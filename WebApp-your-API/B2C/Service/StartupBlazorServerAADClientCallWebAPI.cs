﻿// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Identity.Web;

using Microsoft.AspNetCore.Authentication.JwtBearer;
using TodoListService.AuthorizationPolicies;
using static System.Console;

namespace TodoListService
{
    public class StartupBlazorServerAADClientCallWebAPI
    {
        public StartupBlazorServerAADClientCallWebAPI(IConfiguration configuration)
        {
            Configuration = configuration;
        }

        public IConfiguration Configuration { get; }

        // This method gets called by the runtime. Use this method to add services to the container.
        public void ConfigureServices(IServiceCollection services)
        {
            WriteLine($"Configure Service: begin {nameof(StartupBlazorServerAADClientCallWebAPI)}");
            // Adds Microsoft Identity platform (AAD v2.0) support to protect this Api
            services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
                   .AddMicrosoftIdentityWebApi(options =>
                   {
                       Configuration.Bind("AzureAdB2C", options);

                       options.TokenValidationParameters.NameClaimType = "name";
                   },
           options => { Configuration.Bind("AzureAdB2C", options); });

            services.AddControllers();
            services.AddAuthorization(options =>
            {
                WriteLine($"Service: Adding authorization policies");
                // Create policy to check for the scope 'read'
                options.AddPolicy("ReadScope",
                    policy =>
                    {
                        string acceptedScopes = Configuration["ReadScope"];
                        WriteLine($"Service: ReadScope: {acceptedScopes}");
                        policy.Requirements.Add(new ScopesRequirement(acceptedScopes));
                    });
            });
        }

        // This method gets called by the runtime. Use this method to configure the HTTP request pipeline.
        public void Configure(IApplicationBuilder app, IWebHostEnvironment env)
        {
            WriteLine($"Configure Service: begin {nameof(StartupBlazorServerAADClientCallWebAPI)}");
            if (env.IsDevelopment())
            {
                // Since IdentityModel version 5.2.1 (or since Microsoft.AspNetCore.Authentication.JwtBearer version 2.2.0),
                // PII hiding in log files is enabled by default for GDPR concerns.
                // For debugging/development purposes, one can enable additional detail in exceptions by setting IdentityModelEventSource.ShowPII to true.
                // Microsoft.IdentityModel.Logging.IdentityModelEventSource.ShowPII = true;
                app.UseDeveloperExceptionPage();
            }
            else
            {
                app.UseHsts();
            }

            app.UseHttpsRedirection();
            
            app.UseRouting();
            app.UseAuthentication();
            app.UseAuthorization();

            app.UseEndpoints(endpoints =>
            {
                endpoints.MapControllers();
            });
        }
    }
}