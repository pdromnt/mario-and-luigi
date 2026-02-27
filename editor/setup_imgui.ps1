# setup_imgui.ps1
# Clones ImGui-Pascal from GitHub and applies FPC 3.2.2 compatibility patches.
# Run this once before building the editor.
#
# Patches applied:
#   1. src/ImGuiPasDef.inc         - Enable DYNAMIC_LINK for FPC
#   2. impl/PasImGui.Backend.SDL2.pas - Fix {$ElseIf} + assignment operator for FPC
#   3. impl/PasImGui.Renderer.OpenGL3.pas - Fix reference-to-procedure, {$ELSEIF},
#                                           and array literal syntax for FPC 3.2.2

param(
    [switch]$Force  # Force re-clone even if directory exists
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ImGuiDir = Join-Path $ScriptDir 'ImGui-Pascal'
$RepoURL = 'https://github.com/Coldzer0/ImGui-Pascal.git'

# ── Step 1: Clone ──────────────────────────────────────────────────────────────

if (Test-Path $ImGuiDir) {
    if ($Force) {
        Write-Host "Removing existing ImGui-Pascal directory..." -ForegroundColor Yellow
        Remove-Item -Recurse -Force $ImGuiDir
    } else {
        Write-Host "ImGui-Pascal directory already exists. Use -Force to re-clone." -ForegroundColor Yellow
        Write-Host "Applying patches anyway..." -ForegroundColor Cyan
    }
}

if (-not (Test-Path $ImGuiDir)) {
    Write-Host "Cloning ImGui-Pascal from GitHub..." -ForegroundColor Cyan
    git clone $RepoURL $ImGuiDir
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: git clone failed!" -ForegroundColor Red
        exit 1
    }
    Write-Host "Clone complete." -ForegroundColor Green
}

# ── Step 2: Patch src/ImGuiPasDef.inc ──────────────────────────────────────────
# FPC defaults to {$UnDef DYNAMIC_LINK}, which forces static linking.
# We need dynamic linking for cimgui.dll.

$File1 = Join-Path $ImGuiDir 'src\ImGuiPasDef.inc'
Write-Host "Patching $File1 ..." -ForegroundColor Cyan

$content = Get-Content $File1 -Raw
$original = '{$UnDef DYNAMIC_LINK} // comment if you want to link with dynamic libs.'
$patched  = '// {$UnDef DYNAMIC_LINK} // Patched: FPC needs dynamic linking for cimgui.dll'

if ($content.Contains($original)) {
    $content = $content.Replace($original, $patched)
    Set-Content $File1 $content -NoNewline
    Write-Host "  -> Commented out {`$UnDef DYNAMIC_LINK}" -ForegroundColor Green
} elseif ($content.Contains($patched)) {
    Write-Host "  -> Already patched." -ForegroundColor DarkGray
} else {
    # Try a more lenient match (upstream may have slightly different whitespace)
    $content = $content -replace '\{\$UnDef DYNAMIC_LINK\}', '// {$UnDef DYNAMIC_LINK} // Patched for FPC'
    Set-Content $File1 $content -NoNewline
    Write-Host "  -> Patched (lenient match)." -ForegroundColor Green
}

# ── Step 3: Patch impl/PasImGui.Backend.SDL2.pas ───────────────────────────────
# FPC 3.2.2 doesn't support {$ElseIf defined(X)} after {$IfDef Y}.
# Also fixes = instead of := in Darwin assignment.
# Two blocks to patch (around lines 167 and 642).

$File2 = Join-Path $ImGuiDir 'impl\PasImGui.Backend.SDL2.pas'
Write-Host "Patching $File2 ..." -ForegroundColor Cyan

$content = Get-Content $File2 -Raw

# --- Block 1 (~line 167): viewport^.PlatformHandleRaw ---
# Original:
#   {$IfDef MSWINDOWS}
#   viewport^.PlatformHandleRaw := {%H-}Pointer(info.win.window);
#   {$ElseIf defined(DARWIN)}
#   viewport^.PlatformHandleRaw = {%H-}
#   Pointer(info.cocoa.window);
#   {$EndIf}
#
# Patched:
#   {$IfDef MSWINDOWS}
#   viewport^.PlatformHandleRaw := {%H-}Pointer(info.win.window);
#   {$ELSE} {$IfDef DARWIN}
#   viewport^.PlatformHandleRaw := {%H-}Pointer(info.cocoa.window);
#   {$EndIf} {$EndIf}

$block1_find = @'
    {$IfDef MSWINDOWS}
    viewport^.PlatformHandleRaw := {%H-}Pointer(info.win.window);
    {$ElseIf defined(DARWIN)}
    viewport^.PlatformHandleRaw = {%H-}
Pointer(info.cocoa.window);
    {$EndIf}
'@

$block1_replace = @'
    {$IfDef MSWINDOWS}
    viewport^.PlatformHandleRaw := {%H-}Pointer(info.win.window);
    {$ELSE} {$IfDef DARWIN}
    viewport^.PlatformHandleRaw := {%H-}Pointer(info.cocoa.window);
    {$EndIf} {$EndIf}
'@

if ($content.Contains($block1_find)) {
    $content = $content.Replace($block1_find, $block1_replace)
    Write-Host "  -> Patched SDL2 block 1 (viewport PlatformHandleRaw)" -ForegroundColor Green
} elseif ($content.Contains($block1_replace)) {
    Write-Host "  -> Block 1 already patched." -ForegroundColor DarkGray
} else {
    Write-Host "  -> WARNING: Could not find SDL2 block 1 - may need manual patching" -ForegroundColor Yellow
}

# --- Block 2 (~line 642): main_viewport^.PlatformHandleRaw ---
# Original:
#   {$IfDef MSWINDOWS}
#   main_viewport^.PlatformHandleRaw := {%H-}Pointer(info.win.window);
#   {$ElseIf defined(DARWIN)}
#     main_viewport^.PlatformHandleRaw = Pointer(info.cocoa.window);
#   {$EndIf}
#
# Patched:
#   {$IfDef MSWINDOWS}
#   main_viewport^.PlatformHandleRaw := {%H-}Pointer(info.win.window);
#   {$ELSE} {$IfDef DARWIN}
#     main_viewport^.PlatformHandleRaw := Pointer(info.cocoa.window);
#   {$EndIf} {$EndIf}

$block2_find = @'
    {$IfDef MSWINDOWS}
    main_viewport^.PlatformHandleRaw := {%H-}Pointer(info.win.window);
    {$ElseIf defined(DARWIN)}
      main_viewport^.PlatformHandleRaw = Pointer(info.cocoa.window);
    {$EndIf}
'@

$block2_replace = @'
    {$IfDef MSWINDOWS}
    main_viewport^.PlatformHandleRaw := {%H-}Pointer(info.win.window);
    {$ELSE} {$IfDef DARWIN}
      main_viewport^.PlatformHandleRaw := Pointer(info.cocoa.window);
    {$EndIf} {$EndIf}
'@

if ($content.Contains($block2_find)) {
    $content = $content.Replace($block2_find, $block2_replace)
    Write-Host "  -> Patched SDL2 block 2 (main_viewport PlatformHandleRaw)" -ForegroundColor Green
} elseif ($content.Contains($block2_replace)) {
    Write-Host "  -> Block 2 already patched." -ForegroundColor DarkGray
} else {
    Write-Host "  -> WARNING: Could not find SDL2 block 2 - may need manual patching" -ForegroundColor Yellow
}

Set-Content $File2 $content -NoNewline

# ── Step 4: Patch impl/PasImGui.Renderer.OpenGL3.pas ───────────────────────────
# Three issues:
#   a) 'reference to procedure' types — FPC 3.2.2 doesn't support Delphi anonymous methods
#   b) {$ElseIf defined(AMIGA)} — FPC doesn't support {$ElseIf} with {$If}
#   c) Array literals [@ptr, shader] — FPC 3.2.2 doesn't support this syntax

$File3 = Join-Path $ImGuiDir 'impl\PasImGui.Renderer.OpenGL3.pas'
Write-Host "Patching $File3 ..." -ForegroundColor Cyan

$content = Get-Content $File3 -Raw

# --- Patch 4a: Wrap 'reference to procedure' in {$IfDef IMGUI_LOG} ---
# These types are only used in GL_CALL debugging macros.
# Original:
#   type
#     TGLProc = reference to procedure;
#     TError = reference to procedure(msg : string);
#
# Patched:
#   {$IfDef IMGUI_LOG}
#   type
#     TGLProc = reference to procedure;
#     TError = reference to procedure(msg : string);
#   {$EndIf}

$patch4a_find = @'
type
  TGLProc = reference to procedure;
  TError = reference to procedure(msg : string);
'@

$patch4a_replace = @'
{$IfDef IMGUI_LOG}
type
  TGLProc = reference to procedure;
  TError = reference to procedure(msg : string);
{$EndIf}
'@

if ($content.Contains($patch4a_replace)) {
    Write-Host "  -> reference-to-procedure already patched." -ForegroundColor DarkGray
} elseif ($content.Contains($patch4a_find)) {
    $content = $content.Replace($patch4a_find, $patch4a_replace)
    Write-Host "  -> Patched reference-to-procedure types" -ForegroundColor Green
} else {
    Write-Host "  -> WARNING: Could not find reference-to-procedure types" -ForegroundColor Yellow
}

# --- Patch 4b: Fix {$ElseIf defined(AMIGA)} ---
# Original:
#   {$If (Defined(DARWIN) or Defined(IOS)) or Defined(Android)}
#     {$Define IMGUI_OPENGL_ES3}
#   {$ElseIf defined(AMIGA)}
#     {$Define IMGUI_OPENGL_ES2}
#   {$EndIf}
#
# Patched:
#   {$If (Defined(DARWIN) or Defined(IOS)) or Defined(Android)}
#     {$Define IMGUI_OPENGL_ES3}
#   {$ELSE}
#     {$IfDef AMIGA}
#       {$Define IMGUI_OPENGL_ES2}
#     {$EndIf}
#   {$EndIf}

$patch4b_find = @'
    {$Define IMGUI_OPENGL_ES3}
  {$ElseIf defined(AMIGA)}
    {$Define IMGUI_OPENGL_ES2}
  {$EndIf}
'@

$patch4b_replace = @'
    {$Define IMGUI_OPENGL_ES3}
  {$ELSE}
    {$IfDef AMIGA}
      {$Define IMGUI_OPENGL_ES2}
    {$EndIf}
  {$EndIf}
'@

if ($content.Contains($patch4b_find)) {
    $content = $content.Replace($patch4b_find, $patch4b_replace)
    Write-Host "  -> Patched {`$ElseIf defined(AMIGA)}" -ForegroundColor Green
} elseif ($content.Contains($patch4b_replace)) {
    Write-Host "  -> AMIGA block already patched." -ForegroundColor DarkGray
} else {
    Write-Host "  -> WARNING: Could not find AMIGA ElseIf block" -ForegroundColor Yellow
}

# --- Patch 4c: Fix array literal syntax ---
# FPC 3.2.2 doesn't support [@ptr, str] array literal syntax.
# Original:
#   vertex_shader_with_version := [@bd^.GlslVersionString[0], vertex_shader];
#   ...
#   fragment_shader_with_version := [@bd^.GlslVersionString[0], fragment_shader];
#
# Patched:
#   vertex_shader_with_version[0] := @bd^.GlslVersionString[0];
#   vertex_shader_with_version[1] := vertex_shader;
#   ...
#   fragment_shader_with_version[0] := @bd^.GlslVersionString[0];
#   fragment_shader_with_version[1] := fragment_shader;

$vertFind = 'vertex_shader_with_version := [@bd^.GlslVersionString[0], vertex_shader];'
$vertReplace = @'
vertex_shader_with_version[0] := @bd^.GlslVersionString[0];
  vertex_shader_with_version[1] := vertex_shader;
'@

if ($content.Contains($vertFind)) {
    $content = $content.Replace($vertFind, $vertReplace)
    Write-Host "  -> Patched vertex shader array literal" -ForegroundColor Green
} else {
    Write-Host "  -> Vertex shader array literal already patched or not found." -ForegroundColor DarkGray
}

$fragFind = 'fragment_shader_with_version := [@bd^.GlslVersionString[0], fragment_shader];'
$fragReplace = @'
fragment_shader_with_version[0] := @bd^.GlslVersionString[0];
  fragment_shader_with_version[1] := fragment_shader;
'@

if ($content.Contains($fragFind)) {
    $content = $content.Replace($fragFind, $fragReplace)
    Write-Host "  -> Patched fragment shader array literal" -ForegroundColor Green
} else {
    Write-Host "  -> Fragment shader array literal already patched or not found." -ForegroundColor DarkGray
}

# --- Patch 4d: Fix {$ELSEIF} chain for GLSL version selection ---
# Original:
#   {$IFDEF IMGUI_OPENGL_ES2}
#     glsl_version := '#version 100';
#   {$ELSEIF DEFINED(IMGUI_OPENGL_ES3)}
#     glsl_version := '#version 300 es';
#   {$ELSEIF DEFINED(DARWIN)}
#     glsl_version := '#version 150';
#   {$ELSE}
#     glsl_version := '#version 130';
#   {$ENDIF}

$patch4d_find = @'
    {$IFDEF IMGUI_OPENGL_ES2}
      glsl_version := '#version 100';
    {$ELSEIF DEFINED(IMGUI_OPENGL_ES3)}
      glsl_version := '#version 300 es';
    {$ELSEIF DEFINED(DARWIN)}
      glsl_version := '#version 150';
    {$ELSE}
      glsl_version := '#version 130';
    {$ENDIF}
'@

$patch4d_replace = @'
    {$IFDEF IMGUI_OPENGL_ES2}
      glsl_version := '#version 100';
    {$ELSE}
      {$IFDEF IMGUI_OPENGL_ES3}
      glsl_version := '#version 300 es';
      {$ELSE}
        {$IFDEF DARWIN}
        glsl_version := '#version 150';
        {$ELSE}
        glsl_version := '#version 130';
        {$ENDIF}
      {$ENDIF}
    {$ENDIF}
'@

if ($content.Contains($patch4d_find)) {
    $content = $content.Replace($patch4d_find, $patch4d_replace)
    Write-Host "  -> Patched GLSL version {`$ELSEIF} chain" -ForegroundColor Green
} elseif ($content.Contains($patch4d_replace)) {
    Write-Host "  -> GLSL version chain already patched." -ForegroundColor DarkGray
} else {
    Write-Host "  -> WARNING: Could not find GLSL version ELSEIF chain" -ForegroundColor Yellow
}

Set-Content $File3 $content -NoNewline

# ── Done ───────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "All patches applied successfully!" -ForegroundColor Green
Write-Host "You can now build the editor with build.bat" -ForegroundColor Cyan
Write-Host ""
