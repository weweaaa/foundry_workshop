FROM python:3.11-slim AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# Use the slim container-only requirements (excludes pytest / agent-dev-cli which
# pull conflicting agent-framework-core ranges).
COPY src/research_agent/requirements.txt /app/requirements.txt
RUN pip install --pre -r /app/requirements.txt

# Copy the whole Lab-2-vibe-coding workspace so personas/, skills/, tools/, src/ are all available.
COPY . /app

ENV PYTHONPATH=/app

EXPOSE 8087

CMD ["python", "-m", "src.research_agent.main"]
