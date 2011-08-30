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

if ($db) {
	$res = pg_query("SELECT * FROM gsrpg_players");
	if ($res) {
		while ($row = pg_fetch_array($res)) {
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
		window.location.href = "?node=players;id=" + player;
	}
</script>

<div align="right">
  Sort By:
  <a href="?node=players;sort=level;start=">Level</a> /
  <a href="?node=players;sort=itemsum;start=">Itemsum</a> /
  <a href="?node=players;sort=next;start=">Time to Level</a> /
  <a href="?node=players;sort=username;start=">Username</a> /
  <a href="?node=players;sort=idled;start=">Idled</a><br />

  <strong class="highlight"><span class="vfont">+</span></strong>
  denotes online player,
  <strong class="highlight"><span class="vfont">~</span></strong>
  for offline
</div>

<div align="center">
  <a href="?node=players;sort=;start=0">First</a>&nbsp;&nbsp;
  <a href="?node=players;sort=;start=0">&lt;</a>
  <a href="?node=players;sort=;start=0"><strong class="boo">1</strong></a>
  <a href="?node=players;sort=;start=">&gt;</a>
  &nbsp;&nbsp;<a href="?node=players;sort=;start=0">Last</a>
  <br />
</div>

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
	$id = $p["id"];
	$name = $p["username"];
	$desc = $p["description"];
	$ttl = $p["timeToLevel"];
	$isum = $p["itemsum"];
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
      <a href="?node=players;id=<?php echo $id; ?>"><?php echo $name; ?></a>,
      <?php echo $desc; ?>
    </td>
    <td align="left"><?php echo $ttl; ?></td>
    <td align="left" style="padding: 1px 0;"><?php echo $isum; ?></td>
  </tr>
<?php

}

?>
</table>

<br />
<div align="center">
  <a href="?node=players;sort=;start=0">First</a>&nbsp;&nbsp;
  <a href="?node=players;sort=;start=0">&lt;</a>
  <a href="?node=players;sort=;start=0"><strong class="boo">1</strong></a>
  <a href="?node=players;sort=;start=">&gt;</a>
  &nbsp;&nbsp;<a href="?node=players;sort=;start=0">Last</a>
  <br />
</div>
<?php

/* End of List of Players */

?>
