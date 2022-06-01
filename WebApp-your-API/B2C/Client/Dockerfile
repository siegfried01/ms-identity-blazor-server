#See https://aka.ms/containerfastmode to understand how Visual Studio uses this Dockerfile to build your images for faster debugging.

FROM mcr.microsoft.com/dotnet/aspnet:3.1 AS base
WORKDIR /app
EXPOSE 80
EXPOSE 443

FROM mcr.microsoft.com/dotnet/sdk:3.1 AS build
WORKDIR /src
COPY ["Client/blazorserver-client.csproj", "Client/"]
COPY ["ToDoListModel/ToDoListModel.csproj", "ToDoListModel/"]
RUN dotnet restore "Client/blazorserver-client.csproj"
COPY . .
WORKDIR "/src/Client"
RUN dotnet build "blazorserver-client.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "blazorserver-client.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "blazorserver-client.dll"]