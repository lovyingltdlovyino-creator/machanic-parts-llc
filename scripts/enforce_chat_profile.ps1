$ErrorActionPreference = 'Stop'

$path = 'c:\Users\USER\Desktop\carpartmarket\mechanic_part\lib\main.dart'
if (!(Test-Path -LiteralPath $path)) {
  Write-Error "File not found: $path"
  exit 1
}

$backup = $path + '.bak-' + (Get-Date -Format 'yyyyMMddHHmmss')
Copy-Item -LiteralPath $path -Destination $backup

$content = Get-Content -LiteralPath $path -Raw

$insertBlock = @"
  // Enforce profile completion for buyers before starting chat
  try {
    final profile = await Supabase.instance.client
        .from('profiles')
        .select('profile_completed, user_type')
        .eq('id', user.id)
        .maybeSingle();
    final userType = (profile != null && profile['user_type'] != null)
        ? profile['user_type']
        : (user.userMetadata?['user_type'] ?? 'buyer');
    final completed = profile != null && profile['profile_completed'] == true;
    if (userType == 'buyer' && !completed) {
      final goComplete = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Complete Your Profile'),
          content: const Text('Please complete your profile before contacting sellers.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Later')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Complete Profile')),
          ],
        ),
      );
      if (goComplete == true) {
        context.go('/complete-profile');
      }
      return;
    }
  } catch (_) {
    // If profile check fails, conservatively prompt buyer users based on auth metadata
    final metaType = user.userMetadata?['user_type'] ?? 'buyer';
    if (metaType == 'buyer') {
      final goComplete = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Complete Your Profile'),
          content: const Text('Please complete your profile before contacting sellers.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Later')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Complete Profile')),
          ],
        ),
      );
      if (goComplete == true) {
        context.go('/complete-profile');
      }
      return;
    }
  }
"@

function InsertProfileCheckBlock([string]$content, [string]$funcHeader, [string]$anchorText, [string]$insertBlock) {
  $start = $content.IndexOf($funcHeader)
  if ($start -lt 0) { return $content }
  $anchor = $content.IndexOf($anchorText, $start)
  if ($anchor -lt 0) { return $content }
  $segment = $content.Substring($start, $anchor - $start)
  if ($segment -match 'Complete Your Profile') { return $content }
  return $content.Substring(0, $anchor) + "`r`n" + $insertBlock + "`r`n" + $content.Substring($anchor)
}

$anchorText = 'Check if user is trying to chat with themselves'

$content = InsertProfileCheckBlock $content 'Future<void> _startChat(' $anchorText $insertBlock
$content = InsertProfileCheckBlock $content 'void _showChatPrompt(' $anchorText $insertBlock

Set-Content -LiteralPath $path -Value $content -Encoding UTF8

Write-Host "Backup created at: $backup"
Write-Host "Edits applied to: $path"
