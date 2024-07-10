# Simplified Dockerfile without multistage building

FROM python:3.12.4-slim-bookworm

# Install system dependencies
RUN apt-get update \
  && apt-get install -y build-essential ffmpeg flac make \
  && rm -rf /var/lib/apt/lists/*

# Upgrade pip and install Poetry
RUN pip install --upgrade --no-cache-dir pip && pip install --no-cache-dir poetry

# Set the working directory
WORKDIR /app

# Copy the dependency files
COPY pyproject.toml poetry.lock /app/

# Install dependencies using Poetry
RUN poetry config virtualenvs.create false \
  && poetry install --no-root --only main

# Copy the rest of the project files
COPY . /app

# Expose the application port
EXPOSE 2112

# Set the command to run the application
CMD ["make", "prod"]