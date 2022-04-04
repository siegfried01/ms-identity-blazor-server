using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Configuration;
using Newtonsoft.Json.Linq;
using System;
using System.IO;
using System.Xml.XPath;
using Azure.Identity;
using static System.Console;

namespace blazorserver_client
{
    // dotnet add package Azure.Identity
    // dotnet add package Microsoft.Azure.AppConfiguration.AspNetCore
    // dotnet add package Microsoft.Extensions.Configuration.AzureAppConfiguration
    // dotnet add package JObject
    // dotnet add package Newtonsoft.Json
    
    public class Program
    {
        public static void Main(string[] args)
        {
            CreateHostBuilder(args).Build().Run();
        }

        public static IHostBuilder CreateHostBuilder(string[] args) =>
            Host.CreateDefaultBuilder(args)
                .ConfigureWebHostDefaults(webBuilder =>
                {
                    webBuilder.ConfigureAppConfiguration(config => {
                        var settings = config.Build();
                        var connectionString = settings.GetConnectionString("AppConfig");
                        if (connectionString is null)
                            connectionString = FetchConnectionStringFromSecrets_json(".");

                        config.AddAzureAppConfiguration(options => {
                            options.Connect(connectionString);
                            options.ConfigureKeyVault(options => {
                                options.SetCredential(new DefaultAzureCredential());
                            });
                        });
                    })
                    .UseStartup<Startup>();
                });
        private static string FetchConnectionStringFromSecrets_json(string csprojDirectory)
        {
            var connectionString = "";
            var secrets_jsonPath = @"%USERPROFILE%\AppData\Roaming\Microsoft\UserSecrets\";
            foreach (var fileName in Directory.GetFiles(csprojDirectory))
                if (fileName.EndsWith(".csproj"))
                    secrets_jsonPath += new XPathDocument(fileName).CreateNavigator().Evaluate("string(//*/UserSecretsId/text())");
            secrets_jsonPath += @"\secrets.json";

            var json = File.ReadAllText(Environment.ExpandEnvironmentVariables(secrets_jsonPath));
            JObject connectionJson = JObject.Parse(json);
            connectionString = connectionJson["ConnectionStrings:AppConfig"].Value<string>();
            return connectionString;
        }

    }
}
