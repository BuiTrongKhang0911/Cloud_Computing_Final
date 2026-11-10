FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
COPY students.json .
EXPOSE 8081
CMD ["gunicorn", "--bind", "0.0.0.0:8081", "--workers", "2", "app:app"]
