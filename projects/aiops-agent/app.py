from fastapi import FastAPI, Request
from kubernetes import client, config
from openai import OpenAI
from dotenv import load_dotenv
import os
import time
import pymysql

load_dotenv()

app = FastAPI()

# K8s客户端
try:
    config.load_incluster_config()
except Exception:
    config.load_kube_config(config_file=os.path.expanduser("~/.kube/config"))

v1 = client.CoreV1Api()

# LLM客户端
client = OpenAI(
    api_key=os.getenv("ZHIPU_API_KEY"),
    base_url="https://open.bigmodel.cn/api/paas/v4",
)

DB_CONFIG = {
    "host": "mysql.default.svc.cluster.local",
    "user": "root",
    "password": "Aiops123456",
    "database": "aiops",
    "connect_timeout": 5,
}

@app.get("/health")
def health():
    return {"status": "ok"}

@app.post("/webhook")
async def webhook(request: Request):
    start = time.time()
    data = await request.json()
    results = []

    for alert in data.get("alerts", []):
        alertname = alert["labels"].get("alertname")
        namespace = alert["labels"].get("namespace", "default")
        pod = alert["labels"].get("pod", "")
        description = alert["annotations"].get("description", "")

        print(f"[收到告警] {alertname} | Pod: {pod}", flush=True)

        context = f"告警名称：{alertname}\n命名空间：{namespace}\nPod：{pod}\n描述：{description}\n"

        if pod:
            try:
                logs = v1.read_namespaced_pod_log(pod, namespace, tail_lines=20)
                context += f"\nPod最近日志：\n{logs}\n"
            except Exception as e:
                context += f"\n（无法获取日志：{e}）\n"

        llm_duration = 0
        try:
            diagnosis, llm_duration = call_llm(context)
            print(f"[诊断结果]\n{diagnosis}\n{'='*60}", flush=True)
            results.append({"alert": alertname, "diagnosis": diagnosis})
        except Exception as e:
            print(f"[诊断失败] {e}", flush=True)
            diagnosis = f"分析失败：{e}"
            results.append({"alert": alertname, "diagnosis": diagnosis})

        total_duration = time.time() - start
        save_report(alertname, namespace, pod, description, diagnosis, llm_duration, total_duration)

    print(f"[诊断耗时] {time.time() - start:.2f} 秒", flush=True)
    return {"status": "ok", "results": results}

@app.get("/reports")
def list_reports():
    try:
        conn = pymysql.connect(**DB_CONFIG)
        cursor = conn.cursor(pymysql.cursors.DictCursor)
        cursor.execute("SELECT id, alertname, pod, llm_duration, total_duration, created_at FROM diagnosis_reports ORDER BY created_at DESC LIMIT 20")
        rows = cursor.fetchall()
        conn.close()
        return {"reports": rows}
    except Exception as e:
        return {"error": str(e)}

def call_llm(context):
    start = time.time()
    response = client.chat.completions.create(
        model="glm-4-flash",
        messages=[
            {"role": "system", "content": "你是SRE，分析K8s告警，给出根因和排查建议，简洁。"},
            {"role": "user", "content": f"请分析以下告警：\n\n{context}"}
        ],
        timeout=60
    )
    duration = time.time() - start
    print(f"[LLM 耗时] {duration:.2f} 秒", flush=True)
    return response.choices[0].message.content, duration

def save_report(alertname, namespace, pod, description, diagnosis, llm_duration, total_duration):
    try:
        conn = pymysql.connect(**DB_CONFIG)
        cursor = conn.cursor()
        cursor.execute(
            "INSERT INTO diagnosis_reports (alertname, namespace, pod, description, diagnosis, llm_duration, total_duration) VALUES (%s, %s, %s, %s, %s, %s, %s)",
            (alertname, namespace, pod, description, diagnosis, llm_duration, total_duration)
        )
        conn.commit()
        conn.close()
        print(f"[存储成功] {alertname} - {pod}", flush=True)
    except Exception as e:
        print(f"[存储失败] {e}", flush=True)
