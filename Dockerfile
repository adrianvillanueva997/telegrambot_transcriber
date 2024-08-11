# Simplified Dockerfile without multistage building

FROM python:3.12.5-slim-bookworm

# Install system dependencies
RUN apt-get update \
  && apt-get install -y build-essential ffmpeg flac make \
  && rm -rf /var/lib/apt/lists/*

# Upgrade pip and install Poetry
RUN pip install --upgrade --no-cache-dir pip && pip install --no-cache-dir poetry

# Set the working directory
WORKDIR /app

# Copy the dependency files
COPY . .

# Install dependencies using Poetry
RUN poetry install

# Expose the application port
EXPOSE 2112

# Set the command to run the application
CMD ["make", "prod"]