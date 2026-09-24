from fastapi import FastAPI, Request
from kubernetes import client, config
from openai import OpenAI
from dotenv import load_dotenv
import os

load_dotenv()

app = FastAPI()

# K8s客户端：自动判断容器内还是宿主机
try:
    config.load_incluster_config()
except Exception:
    config.load_kube_config(config_file=os.path.expanduser("~/.kube/config"))

v1 = client.CoreV1Api()

# LLM客户端（智谱 GLM）
client = OpenAI(
    api_key=os.getenv("ZHIPU_API_KEY"),
    base_url="https://open.bigmodel.cn/api/paas/v4",
)

@app.get("/health")
def health():
    return {"status": "ok"}

@app.post("/webhook")
async def webhook(request: Request):
    data = await request.json()
    results = []

    for alert in data.get("alerts", []):
        alertname = alert["labels"].get("alertname")
        namespace = alert["labels"].get("namespace", "default")
        pod = alert["labels"].get("pod", "")
        description = alert["annotations"].get("description", "")

        print(f"[收到告警] {alertname} | Pod: {pod} | 描述: {description}", flush=True)

        context = f"告警名称：{alertname}\n"
        context += f"命名空间：{namespace}\n"
        context += f"Pod：{pod}\n"
        context += f"描述：{description}\n"

        if pod:
            try:
                logs = v1.read_namespaced_pod_log(pod, namespace, tail_lines=50)
                context += f"\nPod最近日志：\n{logs}\n"
            except Exception as e:
                context += f"\n（无法获取日志：{e}）\n"

        try:
            diagnosis = call_llm(context)
            print(f"[诊断结果]\n{diagnosis}\n{'='*60}", flush=True)
            results.append({"alert": alertname, "diagnosis": diagnosis})
        except Exception as e:
            print(f"[诊断失败] {e}", flush=True)
            results.append({"alert": alertname, "diagnosis": f"分析失败：{e}"})

    return {"status": "ok", "results": results}

def call_llm(context):
    response = client.chat.completions.create(
        model="glm-4-flash",
        messages=[
            {"role": "system", "content": "你是一个资深SRE，负责分析K8s告警。给出简洁的根因分析和排查建议。"},
            {"role": "user", "content": f"请分析以下告警：\n\n{context}"}
        ]
    )
    return response.choices[0].message.content
