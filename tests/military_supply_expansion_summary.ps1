$base=Join-Path $PSScriptRoot '../.godot'
$all=@()
foreach($variant in @('supply-expansion-before-final','supply-expansion-results')) {
 $rows=Get-Content -Raw -Encoding utf8 (Join-Path $base "$variant/months.json") | ConvertFrom-Json
 foreach($group in ($rows | Group-Object player,faction)) {
  $last=$group.Group[-1]
  $save=Get-Content -Raw -Encoding utf8 (Join-Path $base "$variant/$($last.player)-60months.json") | ConvertFrom-Json
  $firsts=@{}
  $output=@{}
  for($i=0;$i -lt $group.Group.Count;$i++) {
   $r=$group.Group[$i]
   foreach($city in $r.site_output.PSObject.Properties) {
    if($city.Value.sword -gt 0) {
     if(!$firsts.ContainsKey($city.Name)) {$firsts[$city.Name]=$i+1}
     $output[$city.Name]+=$city.Value.sword
    }
   }
  }
  $orders=@($save.strategy_state.supply_transport.orders.PSObject.Properties.Value | Where-Object {$_.faction_id -eq $last.faction -and $_.original_cargo.sword -gt 0})
  $delivered=($orders.delivered_cargo.sword | Measure-Object -Sum).Sum
  $firstDelivered=($orders | Where-Object status -eq arrived | Sort-Object ended_month | Select-Object -First 1).ended_month
  $entries=@($save.strategy_state.faction_economy.entries | Where-Object faction_id -eq $last.faction)
  $cost=@{}
  foreach($entry in $entries){if($entry.amount -lt 0){$cost[$entry.reason]-=$entry.amount}}
  $all+= [pscustomobject]@{variant=$variant;player=$last.player;faction=$last.faction;initial=1000;income=$last.finance.income;expense=$last.finance.expense;final=$last.finance.balance;troops=$last.troops;recruits=$last.recruits;loss=$last.losses;issued=$last.issued;unarmed=$last.plan.unarmed_people;new_ready=$last.new_ready;training_wait=$last.plan.training_waiting_people;food=$last.food;civilian=$last.civilian;warehouse=$last.weapons;cost=$cost;first_production=$firsts;output=$output;delivered=$delivered;first_delivery=$firstDelivered;raw_shortfall=$last.plan.network.report.raw_military_shortfall;conditional=$last.plan.network.report.conditional_bundles;sites=($last.plan.network.sites.PSObject.Properties.Name);account_ok=(1000+$last.finance.income-$last.finance.expense -eq $last.finance.balance)}
 }
}
[IO.File]::WriteAllText((Join-Path $base 'supply-expansion-results/comparison.json'),($all|ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false))
$all | Format-List