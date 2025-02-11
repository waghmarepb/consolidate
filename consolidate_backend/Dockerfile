# Use Python 3.9 slim image as base
FROM python:3.9-slim

# Set working directory in container
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    python3-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements file
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Create uploads directory and set permissions
RUN mkdir -p uploads && chmod 777 uploads

# Copy the application code
COPY . .

# Set environment variables
ENV FLASK_APP=main.py \
    FLASK_ENV=development \
    PYTHONUNBUFFERED=1

# Expose port 5000
EXPOSE 5000

# Command to run the application
CMD ["python", "main.py"]