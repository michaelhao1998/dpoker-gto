$f = "C:\Users\michaellhao\CodeBuddy\DPoker\prototype\index.html"
$c = [IO.File]::ReadAllText($f)
# Replace renderMiniMatrix with renderHeatmapMatrix
$old = 'function renderMiniMatrix() {'
$new = 'function renderHeatmapMatrix(){'
if ($c.Contains($old)) {
  $c = $c.Replace($old, $new)
  # Replace the matrix title and legend
  $c = $c.Replace('手牌矩阵定位', 'Range Heatmap Matrix')
  $c = $c.Replace('> 当前手牌</div>', '> Current</div>')
  $c = $c.Replace('> 对子</div>', '> Strong</div>')
  $c = $c.Replace('> 同花</div>', '> Marginal</div>')  
  $c = $c.Replace('> 异色</div>', '> Weak</div>')
  
  # Add heatmap function after the closing of renderHeatmapMatrix
  $insert = @"
function getHeatmapStrength(hk){
  var t=PREFLOP_GTO_TABLE.btn_open[hk];
  if(t) return (t.r||0)*(t.r||0)*0.8+(t.c||0)*0.15+0.05);
  var e=estimateHandFromNeighbors(hk,PREFLOP_GTO_TABLE.btn_open);
  return (e.r||0)*0.7+(e.c||0)*0.2+0.1;
}
"@
  # Insert before </script>
  $c = $c.Replace('</script>', $insert + '`n</script>')
  # Also replace the call site
  $c = $c.Replace('renderMiniMatrix()', 'renderHeatmapMatrix()')
  
  [IO.File]::WriteAllText($f, $c, [System.Text.UTF8Encoding]::new($false))
  Write-Host "HEATMAP DONE"
} else {
  Write-Host "NOT FOUND: renderMiniMatrix"
}
