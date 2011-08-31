<?php

/*
 * List of Teams
 * Written 2011 by David Herrmann
 */

/*
 * This lists all available teams.
 * Single-Team detail list is still TODO.
 */

$teams = array();
$sort = "name";
if (isset($_GET["sort"]))
	$sort = $_GET["sort"];

if ($db) {
	$orderby = "";

	if ($sort == "teamid")
		$orderby = 'ORDER BY teamid ASC';
	elseif ($sort == "owner")
		$orderby = 'ORDER BY "owner" ASC';
	else
		$orderby = 'ORDER BY name ASC';

	$res = pg_query('SELECT teamid, name, description, "owner", "password"
			 FROM gsrpg_teams ' . $orderby);
	if ($res) {
		while ($row = pg_fetch_array($res)) {
			$sql = pg_query("SELECT USERNAME(".$row["owner"].")");
			$isum = pg_fetch_array($sql);
			$row["owner"] = $isum[0];
			pg_free_result($sql);
			$sql = pg_query("SELECT MEMBERS(".$row["teamid"].")");
			$isum = pg_fetch_array($sql);
			$row["members"] = $isum[0];
			pg_free_result($sql);
			$teams[] = $row;
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
		window.location.href =
			"?node=teams&id="+player;
	}
</script>

<div align="right">
	Sort By: <a href="?node=teams&sort=teamid">TeamID</a> /
	<a href="?node=teams&sort=name">Name</a> /
	<a href="?node=teams&sort=owner">Owner</a>
</div>
<br />

<table border="0" cellpadding="0" cellspacing="0" id="players">
  <tr>
    <th width="5%" align="left">#</th>
    <th width="20%" align="left">Name</th>
    <th width="45%" align="left">Description</th>
    <th width="7%" align="left">Owner</th>
    <th width="7%" align="left">Members</th>
    <th width="5%" align="left">Locked</th>
  </tr>
<?php

$i = 1;
foreach($teams as $v) {
	$id = $v["teamid"];
	$name = $v["name"];
	$desc = $v["description"];
	$owner = $v["owner"];
	$members = $v["members"];
	if (strlen($v["password"]) > 0)
		$locked = "Yes";
	else
		$locked = "No";

?>
  <tr onmouseover="hoverRow(this,'on');"
      onmouseout="hoverRow(this,'off');"
      onclick="clickRow('<?php echo $id; ?>');">
    <td align="left"><strong><?php echo $i++; ?></strong></td>
    <td align="left">
      <a href="?node=teams&id=<?php echo $id; ?>"><?php echo $name; ?></a>
    </td>
    <td align="left"><?php echo $desc; ?></td>
    <td align="left"><?php echo $owner; ?></td>
    <td align="left" style="padding: 1px 0;"><?php echo $members; ?></td>
    <td align="left" style="padding: 1px 0;"><?php echo $locked; ?></td>
  </tr>
<?php

}

?>
</table>
<?php

/* End of List of Teams */

?>
