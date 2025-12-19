FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Default to frontend app, can be overridden
ENV APP_TYPE=frontend

CMD if [ "$APP_TYPE" = "backend" ]; then \
        gunicorn -b 0.0.0.0:5001 backend:app; \
    else \
        gunicorn -b 0.0.0.0:5000 app:app; \
    fi
