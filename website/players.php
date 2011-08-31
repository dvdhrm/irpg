<?php

/*
 * List of Players
 * Written 2011 by David Herrmann
 */

/*
 * Create list of players dynamically from database.
 * Individual player view still TODO.
 */

/* initialize dynamicly retrieved data */
$players = array();
$sort = "level";
if (isset($_GET["sort"]))
	$sort = $_GET["sort"];

if ($db) {
	$orderby = "";

	if ($sort == "next")
		$orderby = "ORDER BY next ASC";
	elseif ($sort == "username")
		$orderby = "ORDER BY username ASC";
	elseif ($sort == "idled")
		$orderby = "ORDER BY idled DESC";
	else
		$orderby = "ORDER BY level DESC";

	$res = pg_query("SELECT playerid, username, level, class, next, online
	FROM gsrpg_players " . $orderby);
	if ($res) {
		while ($row = pg_fetch_array($res)) {
			$sql = pg_query("SELECT ITEMSUM(".$row["playerid"].")");
			$isum = pg_fetch_array($sql);
			$row["isum"] = $isum[0];
			pg_free_result($sql);
			$players[] = $row;
		}
		pg_free_result($res);
	}
}

?>
<script language="javascript" type="text/javascript">
	function hoverRow(obj, state) {
		obj.style.background = ((state == "on") ? "#dddddd" : "#ffffff");
		obj.style.cursor = "pointer";
	}
	function clickRow(player) {
		window.location.href = "?node=players&id=" + player;
	}
</script>

<div align="right">
  Sort By:
  <a href="?node=players&sort=level">Level</a> /
  <a href="?node=players&sort=itemsum">Itemsum</a> /
  <a href="?node=players&sort=next">Time to Level</a> /
  <a href="?node=players&sort=username">Username</a> /
  <a href="?node=players&sort=idled">Idled</a><br />

  <strong class="highlight"><span class="vfont">+</span></strong>
  denotes online player,
  <strong class="highlight"><span class="vfont">~</span></strong>
  for offline
</div>

<br>

<table border="0" cellpadding="0" cellspacing="0" id="players">
  <tr>
    <th width="5%" align="left">#</th>
    <th width="70%" align="left">Player</th>
    <th width="18%" align="left">Time to Level</th>
    <th width="7%" align="left">Itemsum</th>
  </tr>
<?php

$i = 1;
foreach($players as $p) {
	$id = $p["playerid"];
	$name = $p["username"];
	$level = $p["level"];
	$desc = $p["class"];
	$ttl = $p["next"];
	$isum = $p["isum"];
	$online = "~";
	if ($p["online"])
		$online = "+";

?>
  <tr onmouseover="hoverRow(this, 'on');"
      onmouseout="hoverRow(this, 'off');"
      onclick="clickRow('<?php echo $id; ?>');">
    <td align="left"><strong><?php echo $i++; ?></strong></td>
    <td align="left">
      <strong class="vfont"><?php echo $online; ?></strong>
      <a href="?node=players&id=<?php echo $id; ?>"><?php echo $name; ?></a>,
      the level <?php echo $level; ?> <?php echo $desc; ?>
    </td>
    <td align="left"><?php echo $ttl; ?></td>
    <td align="left" style="padding: 1px 0;"><?php echo $isum; ?></td>
  </tr>
<?php

}

?>
</table>
<?php

/* End of List of Players */

?>
