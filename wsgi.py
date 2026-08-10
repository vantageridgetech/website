from app import create_app

app = create_app()

if __name__ == "__main__":
    host = "127.0.0.1"
    if app.config.get("APP_ENV") == "container":
        host = "0.0.0.0"  # nosec B104 - required to expose Flask from Docker container
    app.run(host=host, port=5000)
