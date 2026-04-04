docker build -f docker/DemoApi.Dockerfile -t demoapi:local .
docker run -p 8080:80 demoapi:local