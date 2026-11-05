using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using WarehouseCollecto.Api.Data;
var builder=WebApplication.CreateBuilder(args);
builder.Services.AddDbContext<AppDbContext>(o=>o.UseSqlite(builder.Configuration.GetConnectionString("Warehouse")??"Data Source=warehouse-collecto.db"));
builder.Services.AddScoped<IPasswordHasher<AppUser>,PasswordHasher<AppUser>>();
var secret=builder.Configuration["JWT_SECRET"];
if(string.IsNullOrWhiteSpace(secret)||Encoding.UTF8.GetByteCount(secret)<32) throw new InvalidOperationException("JWT_SECRET must contain at least 32 UTF-8 bytes.");
var key=new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secret));
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer(o=>o.TokenValidationParameters=new TokenValidationParameters { ValidateIssuer=true,ValidIssuer="WarehouseCollecto",ValidateAudience=true,ValidAudience="WarehouseCollecto.Mobile",ValidateIssuerSigningKey=true,IssuerSigningKey=key,ValidateLifetime=true,ClockSkew=TimeSpan.FromSeconds(30) });
builder.Services.AddAuthorization();
builder.WebHost.UseUrls(builder.Configuration["ASPNETCORE_URLS"]??"http://0.0.0.0:5080");
var app=builder.Build();
await using(var scope=app.Services.CreateAsyncScope()) await scope.ServiceProvider.GetRequiredService<AppDbContext>().Database.EnsureCreatedAsync();
app.UseAuthentication(); app.UseAuthorization();
app.MapGet("/health",()=>Results.Ok(new {status="ok",service="WarehouseCollecto API"}));
app.MapPost("/api/auth/bootstrap",async(BootstrapRequest r,AppDbContext db,IPasswordHasher<AppUser> h,IConfiguration c)=>{
 if(string.IsNullOrWhiteSpace(c["BOOTSTRAP_KEY"])||r.BootstrapKey!=c["BOOTSTRAP_KEY"]) return Results.Unauthorized();
 if(await db.Users.AnyAsync()) return Results.Conflict(new {message="Bootstrap already completed."});
 if(r.Username.Trim().Length<3||r.Password.Length<12||string.IsNullOrWhiteSpace(r.DisplayName)||string.IsNullOrWhiteSpace(r.DistributorCode)) return Results.BadRequest();
 var u=new AppUser{Username=r.Username.Trim(),DisplayName=r.DisplayName.Trim(),DistributorCode=r.DistributorCode.Trim().ToUpperInvariant(),Role="admin"}; u.PasswordHash=h.HashPassword(u,r.Password); db.Users.Add(u); await db.SaveChangesAsync(); return Results.Created("/api/auth/bootstrap",new {u.Id,u.Username,u.Role});
});
app.MapPost("/api/auth/login",async(LoginRequest r,AppDbContext db,IPasswordHasher<AppUser> h)=>{
 var u=await db.Users.SingleOrDefaultAsync(x=>x.Username==r.Username.Trim());
 if(u is null||!u.IsActive||h.VerifyHashedPassword(u,u.PasswordHash,r.Password)==PasswordVerificationResult.Failed) return Results.Unauthorized();
 var claims=new[]{new Claim(ClaimTypes.NameIdentifier,u.Id.ToString()),new Claim(ClaimTypes.Name,u.Username),new Claim(ClaimTypes.Role,u.Role),new Claim("distributor_code",u.DistributorCode)};
 var token=new JwtSecurityToken("WarehouseCollecto","WarehouseCollecto.Mobile",claims,expires:DateTime.UtcNow.AddHours(8),signingCredentials:new SigningCredentials(key,SecurityAlgorithms.HmacSha256));
 return Results.Ok(new LoginResponse(new JwtSecurityTokenHandler().WriteToken(token),u.Username,u.DisplayName,u.DistributorCode,u.Role,token.ValidTo));
});
var admin=app.MapGroup("/api/admin").RequireAuthorization(p=>p.RequireRole("admin"));
admin.MapGet("/users",async(AppDbContext db)=>Results.Ok(await db.Users.OrderBy(x=>x.Username).Select(x=>new UserResponse(x.Id,x.Username,x.DisplayName,x.DistributorCode,x.Role,x.IsActive)).ToListAsync()));
admin.MapPost("/customers/import", async(CustomerImportRequest request, AppDbContext db) =>
{
    if (request.Customers.Count > 2000) return Results.BadRequest(new { message = "Maximum batch size is 2000." });
    foreach (var item in request.Customers)
    {
        if (string.IsNullOrWhiteSpace(item.Code) || string.IsNullOrWhiteSpace(item.Name) ||
            item.Code.Length > 60 || item.Name.Length > 200 ||
            item.BalanceYer < 0 || item.BalanceSar < 0 || item.BalanceUsd < 0)
            return Results.BadRequest(new { message = "Invalid customer data." });
        var code = item.Code.Trim();
        var customer = await db.Customers.FindAsync(code);
        if (customer is null)
        {
            customer = new Customer { Code = code };
            db.Customers.Add(customer);
        }
        customer.Name = item.Name.Trim();
        customer.Area = item.Area ?? "";
        customer.Phone = item.Phone ?? "";
        customer.BalanceYer = item.BalanceYer;
        customer.BalanceSar = item.BalanceSar;
        customer.BalanceUsd = item.BalanceUsd;
        customer.UpdatedAtUtc = DateTime.UtcNow;
    }
    await db.SaveChangesAsync();
    return Results.Ok(new { imported = request.Customers.Count });
});
admin.MapPost("/users",async(CreateUserRequest r,AppDbContext db,IPasswordHasher<AppUser> h)=>{
 if(r.Username.Trim().Length<3||r.Password.Length<12||string.IsNullOrWhiteSpace(r.DisplayName)||string.IsNullOrWhiteSpace(r.DistributorCode)||(r.Role!="admin"&&r.Role!="distributor")) return Results.BadRequest();
 var u=new AppUser{Username=r.Username.Trim(),DisplayName=r.DisplayName.Trim(),DistributorCode=r.DistributorCode.Trim().ToUpperInvariant(),Role=r.Role}; u.PasswordHash=h.HashPassword(u,r.Password); db.Users.Add(u);
 try{await db.SaveChangesAsync();}catch(DbUpdateException){return Results.Conflict(new {message="Username or distributor code already exists."});}
 return Results.Created($"/api/admin/users/{u.Id}",new UserResponse(u.Id,u.Username,u.DisplayName,u.DistributorCode,u.Role,u.IsActive));
});
admin.MapPatch("/users/{id:long}/active",async(long id,SetActiveRequest r,AppDbContext db)=>{var u=await db.Users.FindAsync(id);if(u is null)return Results.NotFound();u.IsActive=r.IsActive;await db.SaveChangesAsync();return Results.NoContent();});
admin.MapPost("/users/{id:long}/reset-password",async(long id,ResetPasswordRequest r,AppDbContext db,IPasswordHasher<AppUser> h)=>{if(r.NewPassword.Length<12)return Results.BadRequest();var u=await db.Users.FindAsync(id);if(u is null)return Results.NotFound();u.PasswordHash=h.HashPassword(u,r.NewPassword);await db.SaveChangesAsync();return Results.NoContent();});
var api=app.MapGroup("/api").RequireAuthorization();
api.MapGet("/customers",async(AppDbContext db)=>Results.Ok(await db.Customers.OrderBy(x=>x.Name).ToListAsync()));
api.MapPost("/sync/receipts",async(SyncReceiptsRequest r,ClaimsPrincipal p,AppDbContext db)=>{
 var distributor=p.FindFirstValue("distributor_code");if(string.IsNullOrWhiteSpace(distributor))return Results.Forbid();if(r.Receipts.Count>250)return Results.BadRequest();
 var accepted=new List<string>();
 foreach(var x in r.Receipts){
  if(x.Amount<=0||decimal.Round(x.Amount,2)!=x.Amount||x.OperationId.Length is <12 or >80||x.DistributorCode!=distributor)return Results.BadRequest();
  if(await db.Receipts.AnyAsync(y=>y.OperationId==x.OperationId)){accepted.Add(x.OperationId);continue;}
  if(x.Method=="حوالة"&&!string.IsNullOrWhiteSpace(x.TransferRef)&&await db.Receipts.AnyAsync(y=>y.Method=="حوالة"&&y.Network==x.Network&&y.TransferRef==x.TransferRef))return Results.Conflict(new {message="Duplicate transfer reference.",operationId=x.OperationId});
  db.Receipts.Add(new Receipt{OperationId=x.OperationId,Number=x.Number,DistributorCode=distributor,CustomerCode=x.CustomerCode,CustomerName=x.CustomerName,Amount=x.Amount,Currency=x.Currency,Method=x.Method,Network=x.Network,TransferRef=x.TransferRef,Note=x.Note,CreatedAtUtc=x.CreatedAtUtc.ToUniversalTime()});accepted.Add(x.OperationId);
 }
 await db.SaveChangesAsync();return Results.Ok(new{acceptedOperationIds=accepted});
});
app.Run();
record BootstrapRequest(string BootstrapKey,string Username,string DisplayName,string DistributorCode,string Password);
record LoginRequest(string Username,string Password);
record LoginResponse(string AccessToken,string Username,string DisplayName,string DistributorCode,string Role,DateTime ExpiresAtUtc);
record CreateUserRequest(string Username,string DisplayName,string DistributorCode,string Password,string Role);
record UserResponse(long Id,string Username,string DisplayName,string DistributorCode,string Role,bool IsActive);
record SetActiveRequest(bool IsActive);
record ResetPasswordRequest(string NewPassword);
record CustomerImportRequest(List<CustomerImportItem> Customers);
record CustomerImportItem(string Code,string Name,string? Area,string? Phone,decimal BalanceYer,decimal BalanceSar,decimal BalanceUsd);
record SyncReceiptsRequest(List<ReceiptSyncItem> Receipts);
record ReceiptSyncItem(string OperationId,string Number,string DistributorCode,string CustomerCode,string CustomerName,decimal Amount,string Currency,string Method,string? Network,string? TransferRef,string? Note,DateTime CreatedAtUtc);