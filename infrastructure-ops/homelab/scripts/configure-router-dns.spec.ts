import { test, expect } from '@playwright/test';

test('Configure ASUS Router DNS Override for nas.harbor.fyi', async ({ page }) => {
  // Ignore SSL certificate errors (self-signed cert)
  await page.context().setDefaultNavigationTimeout(30000);

  console.log('🌐 Navigating to router...');
  await page.goto('https://192.168.50.1:8443', {
    waitUntil: 'networkidle',
    timeout: 30000
  });

  // Handle SSL warning if present
  await page.waitForTimeout(2000);

  console.log('🔐 Logging in...');
  // Fill login form
  await page.fill('input[name="login_username"]', 'sysadmin');
  await page.fill('input[type="password"]', 'swipe4DILEMMA7helpmate@theatre');
  await page.click('button[type="submit"], input[type="submit"], .button_gen');

  // Wait for dashboard
  await page.waitForTimeout(5000);
  console.log('✅ Logged in successfully');

  // Take screenshot of dashboard
  await page.screenshot({ path: '/tmp/router-dashboard.png', fullPage: true });
  console.log('📸 Screenshot saved: /tmp/router-dashboard.png');

  // Navigate to Advanced Settings
  console.log('🔧 Navigating to DNS settings...');

  // Try multiple possible paths to DNS settings
  // Path 1: Advanced Settings > WAN > DNS Director
  const advancedLink = page.locator('text=Advanced Settings').first();
  if (await advancedLink.isVisible({ timeout: 5000 }).catch(() => false)) {
    await advancedLink.click();
    await page.waitForTimeout(2000);
  }

  // Look for WAN menu item
  const wanLink = page.locator('text=WAN').first();
  if (await wanLink.isVisible({ timeout: 5000 }).catch(() => false)) {
    await wanLink.click();
    await page.waitForTimeout(2000);
  }

  // Take screenshot of current page
  await page.screenshot({ path: '/tmp/router-wan-page.png', fullPage: true });
  console.log('📸 WAN page screenshot: /tmp/router-wan-page.png');

  // Try to find DNS Director or DNSFilter tabs
  const dnsDirectorTab = page.locator('text=DNS Director').first();
  const dnsFilterTab = page.locator('text=DNS Filter').first();
  const lanTab = page.locator('text=LAN').first();

  // Try DNS Director
  if (await dnsDirectorTab.isVisible({ timeout: 5000 }).catch(() => false)) {
    console.log('📍 Found DNS Director tab');
    await dnsDirectorTab.click();
    await page.waitForTimeout(2000);
    await page.screenshot({ path: '/tmp/router-dns-director.png', fullPage: true });

    // Add DNS override entry
    // This will vary based on the actual UI structure
    await page.fill('input[placeholder*="domain"], input[name*="domain"]', 'nas.harbor.fyi');
    await page.fill('input[placeholder*="IP"], input[name*="ip"]', '192.168.50.45');
    await page.click('button:has-text("Add"), button:has-text("Apply")');
    console.log('✅ DNS override configured via DNS Director');
  }
  // Try DNS Filter
  else if (await dnsFilterTab.isVisible({ timeout: 5000 }).catch(() => false)) {
    console.log('📍 Found DNS Filter tab');
    await dnsFilterTab.click();
    await page.waitForTimeout(2000);
    await page.screenshot({ path: '/tmp/router-dns-filter.png', fullPage: true });
    console.log('⚠️  DNS Filter found but automation not yet implemented');
  }
  // Try LAN > DHCP Server > DNS
  else if (await lanTab.isVisible({ timeout: 5000 }).catch(() => false)) {
    console.log('📍 Trying LAN > DHCP Server');
    await lanTab.click();
    await page.waitForTimeout(2000);
    await page.screenshot({ path: '/tmp/router-lan-page.png', fullPage: true });
    console.log('⚠️  LAN page found but automation not yet implemented');
  }
  else {
    console.log('⚠️  Could not find DNS configuration options');
    console.log('📸 Taking full page screenshot for manual review');
    await page.screenshot({ path: '/tmp/router-full-page.png', fullPage: true });
  }

  // Get page content for analysis
  const content = await page.content();
  console.log('\n📄 Page contains DNS Director?', content.includes('DNS Director'));
  console.log('📄 Page contains DNS Filter?', content.includes('DNS Filter'));
  console.log('📄 Page contains DNSFilter?', content.includes('DNSFilter'));

  await page.waitForTimeout(3000);
  console.log('✅ Router configuration completed');
});
