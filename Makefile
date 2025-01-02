local:
	docker build -t test . --debug
	docker run -e BOT_TOKEN=$BOT_TOKEN -p 2112:2112 test
prod:
	uv run python src/transcriber_telegrambot/main.py
installdeps:
	uv sync