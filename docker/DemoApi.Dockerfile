# Stage 1: Build the application
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /app

COPY . .

RUN dotnet restore ./src/DemoApi/DemoApi.csproj
RUN dotnet publish ./src/DemoApi/DemoApi.csproj -c Release -o /app/publish

# Stage 2: Runtime
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app
COPY --from=build /app/publish .
# Create non-root user and group
RUN addgroup --system appgroup && \
    adduser --system --ingroup appgroup appuser

# Give ownership of app files to non-root user
RUN chown -R appuser:appgroup /app

# Switch to non-root user before running
USER appuser
ENTRYPOINT ["dotnet", "DemoApi.dll"]
