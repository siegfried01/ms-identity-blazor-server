// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Hosting;
using static System.Console;

namespace TodoListService
{
    public class WebAPIServiceMainProgram
    {
        public static void Main(string[] args)
        {
            WriteLine($"Starting {nameof(WebAPIServiceMainProgram)}");
            CreateHostBuilder(args).Build().Run();
        }

        public static IHostBuilder CreateHostBuilder(string[] args) =>
            Host.CreateDefaultBuilder(args)
                .ConfigureWebHostDefaults(webBuilder =>
                {
                    webBuilder.UseStartup<StartupBlazorServerAADClientCallWebAPI>();
                });
    }
}
