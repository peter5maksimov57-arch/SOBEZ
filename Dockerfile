# Используем официальный CPU-образ vLLM как базу (версия >= 0.27.0)
# Примечание: точный тег необходимо уточнить в документации vLLM.
FROM vllm/vllm-openai-cpu:latest AS base

# Переключаемся на root для установки зависимостей
USER root

# Устанавливаем pinned-зависимости
COPY requirements.txt /tmp/requirements.txt
ENV VLLM_TARGET_DEVICE=cpu
RUN pip install --no-cache-dir -r /tmp/requirements.txt

# Копируем конфигурацию логирования и скрипт загрузки модели
COPY scripts/logging_config.json /etc/vllm/logging_config.json
COPY scripts/download_model.sh /usr/local/bin/download_model.sh
RUN sed -i 's/\r$//' /usr/local/bin/download_model.sh && \
    chmod +x /usr/local/bin/download_model.sh

# Создаем непривилегированного пользователя и группу
RUN groupadd --gid 1000 vllm && \
    useradd --uid 1000 --gid vllm --create-home --shell /bin/bash vllm

# Даем права на директорию кэша Hugging Face
RUN mkdir -p /home/vllm/.cache/huggingface && \
    chown -R vllm:vllm /home/vllm/.cache

# Принудительно включаем CPU-платформу для vLLM, чтобы обойти баг автоопределения устройства
RUN cat << 'EOF' > /tmp/patch_vllm.py
import os
import glob

# Ищем файл platforms/__init__.py (путь может отличаться в зависимости от версии Python)
init_files = glob.glob('/opt/venv/lib/python*/site-packages/vllm/platforms/__init__.py')
if init_files:
    init_file = init_files[0]
    with open(init_file, 'r') as f:
        content = f.read()
    
    patch_code = "from .cpu import CpuPlatform\ncurrent_platform = CpuPlatform()\n"
    if 'current_platform = CpuPlatform()' not in content:
        with open(init_file, 'w') as f:
            f.write(patch_code + content)
EOF
RUN python /tmp/patch_vllm.py && rm /tmp/patch_vllm.py

# Переключаемся на непривилегированного пользователя
USER vllm
WORKDIR /home/vllm

# Точка входа будет использовать скрипт загрузки модели,
# если модель еще не скачана, а затем запустит vLLM.
ENTRYPOINT ["/usr/local/bin/download_model.sh"]
CMD ["vllm", "serve", "--host", "0.0.0.0", "--port", "8000"]