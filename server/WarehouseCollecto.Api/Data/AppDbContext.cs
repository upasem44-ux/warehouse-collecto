using Microsoft.EntityFrameworkCore;
namespace WarehouseCollecto.Api.Data;
public sealed class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<AppUser> Users => Set<AppUser>();
    public DbSet<Customer> Customers => Set<Customer>();
    public DbSet<Receipt> Receipts => Set<Receipt>();
    public DbSet<AuthAudit> AuditLogs => Set<AuthAudit>();
    protected override void OnModelCreating(ModelBuilder b)
    {
        b.Entity<AppUser>(e => { e.HasIndex(x => x.Username).IsUnique(); e.HasIndex(x => x.DistributorCode).IsUnique(); e.Property(x => x.Username).HasMaxLength(80).IsRequired(); e.Property(x => x.DisplayName).HasMaxLength(160).IsRequired(); e.Property(x => x.DistributorCode).HasMaxLength(40).IsRequired(); e.Property(x => x.PasswordHash).IsRequired(); });
        b.Entity<AuthAudit>(e => { e.Property(x => x.Username).HasMaxLength(80).IsRequired(); e.Property(x => x.Event).HasMaxLength(80).IsRequired(); e.Property(x => x.IpAddress).HasMaxLength(64); });
        b.Entity<Customer>(e => { e.HasKey(x => x.Code); e.Property(x => x.Code).HasMaxLength(60); e.Property(x => x.Name).HasMaxLength(200).IsRequired(); e.Property(x => x.BalanceYer).HasPrecision(18,2); e.Property(x => x.BalanceSar).HasPrecision(18,2); e.Property(x => x.BalanceUsd).HasPrecision(18,2); });
        b.Entity<Receipt>(e => { e.HasIndex(x => x.OperationId).IsUnique(); e.HasIndex(x => new { x.Network, x.TransferRef }).IsUnique().HasFilter("\"Method\" = 'حوالة' AND \"TransferRef\" IS NOT NULL AND \"TransferRef\" <> ''"); e.Property(x => x.Amount).HasPrecision(18,2); e.Property(x => x.Number).HasMaxLength(100).IsRequired(); e.Property(x => x.DistributorCode).HasMaxLength(40).IsRequired(); e.Property(x => x.CustomerCode).HasMaxLength(60).IsRequired(); e.Property(x => x.Currency).HasMaxLength(8).IsRequired(); e.Property(x => x.Method).HasMaxLength(40).IsRequired(); e.Property(x => x.OperationId).HasMaxLength(80).IsRequired(); });
    }
}
public sealed class AppUser { public long Id {get;set;} public string Username {get;set;}=""; public string DisplayName {get;set;}=""; public string DistributorCode {get;set;}=""; public string Role {get;set;}="distributor"; public string PasswordHash {get;set;}=""; public bool IsActive {get;set;}=true; public int FailedAttempts {get;set;} public DateTime? LockedUntilUtc {get;set;} public DateTime CreatedAtUtc {get;set;}=DateTime.UtcNow; }
public sealed class AuthAudit { public long Id {get;set;} public string Username {get;set;}=""; public string Event {get;set;}=""; public string? IpAddress {get;set;} public DateTime CreatedAtUtc {get;set;}=DateTime.UtcNow; }
public sealed class Customer { public string Code {get;set;}=""; public string Name {get;set;}=""; public string Area {get;set;}=""; public string Phone {get;set;}=""; public decimal BalanceYer {get;set;} public decimal BalanceSar {get;set;} public decimal BalanceUsd {get;set;} public DateTime UpdatedAtUtc {get;set;}=DateTime.UtcNow; }
public sealed class Receipt { public long Id {get;set;} public string OperationId {get;set;}=""; public string Number {get;set;}=""; public string DistributorCode {get;set;}=""; public string CustomerCode {get;set;}=""; public string CustomerName {get;set;}=""; public decimal Amount {get;set;} public string Currency {get;set;}="yer"; public string Method {get;set;}=""; public string? Network {get;set;} public string? TransferRef {get;set;} public string? Note {get;set;} public DateTime CreatedAtUtc {get;set;}=DateTime.UtcNow; }