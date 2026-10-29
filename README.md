Тестовое задание: Развертывание vLLM на CPU в Kubernetes

Решение разворачивает OpenSource-модель `Qwen/Qwen2.5-0.5B-Instruct` с использованием фреймворка vLLM (v0.27.0). 
Инференс настроен строго на CPU. В качестве среды развертывания используется Kubernetes (Docker Desktop).

Структура проекта
- `Dockerfile` — сборка rootless-образа с зафиксированными зависимостями (pinned dependencies).
- `scripts/download_model.sh` — скрипт кэширования модели (вызывается в `initContainer`).
- `scripts/logging_config.json` — кастомная конфигурация логирования vLLM (скрывает промпты и ответы).
- `k8s/base/` — набор манифестов (Namespace, PVC, Secret, ConfigMap, Deployment, Service) для деплоя.

Как развернуть локально

1. Сборка Docker-образа:
   ```bash
   docker build -t my-vllm-cpu:latest .
   ```

2. Применение манифестов в K8s:
   ```bash
   kubectl apply -k k8s/base
   ```

3. Проверка статуса пода (ожидаем статус Running):
   ```bash
   kubectl get pods -n vllm -w
   ```

4. Проброс порта для доступа к API:
   ```bash
   kubectl port-forward svc/vllm-server 8000:8000 -n vllm
   ```

5. Проверка работы API:
   Откройте в браузере http://localhost:8000/docs.