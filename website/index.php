<?php

/*
 * Main Page
 * Written 2011 by David Herrmann
 */

/*
 * Create basic HTML layout and include the requested user page.
 * TODO: The sidebar should be created dynamically.
 */

/* global config */
$root = "/"; // Root website path
$title = "OnlineGamesNet Idle RPG"; // Website title
$dbhost = "87.118.119.6"; // DB host
$dbuser = "irpg"; // DB username
$dbpass = "pass"; // DB password
$dbname = "irpg"; // DB database name

/* set page node */
$node = "players";
if (isset($_GET["node"]))
	$node = $_GET["node"];

/* preset dynamically loaded variables */
$players_total = "0";
$players_online = "0";
$uptime = "0 days, 0:0:0";
$traffic1 = "0 kb";
$traffic2 = "0 kb";
$chan_size = "0";
$chan_bans = "0";

/* connect to DB */
$db = @pg_connect("host=$dbhost dbname=$dbname user=$dbuser password=$dbpass");

?>
<!DOCTYPE HTML>
<html>
  <head>
    <title><?php echo $title; ?></title>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
    <link rel="stylesheet" media="all" type="text/css" href="irpg.css" />
  </head>

  <body>
    <div id="maintitle">
      <a href="<?php echo $root; ?>">OGameNet Idle RPG</a>
    </div>
    <table border="0" cellpadding="0" cellspacing="0" id="content"> 
      <tr>
        <td id="main" valign="top">
          <br>
<?php

if ($node == "teams")
	include("teams.php");
else if ($node == "stats")
	include("stats.php");
else if ($node == "commands")
	include("commands.php");
else
	include("players.php");

?>
        </td>
        <td id="right" valign="top">

          <table border="0" cellpadding="0" cellspacing="0" class="box">
            <tr>
              <th valign="middle">Navigation</th>
            </tr>
            <tr>
              <td>
                Idle RPG
                <br />
                &#149; <a href="?node=players">Idlers</a>
                <br />
                &#149; <a href="?node=teams">Teams</a>
                <br />
                &#149; <a href="?node=stats">Statistics</a>
                <br />
                &#149; <a href="?node=commands">Command List</a>
                <br />
              </td>
            </tr>
          </table>
          <br />

          <table border="0" cellpadding="0" cellspacing="0" class="box">
            <tr>
              <th>Current Stats</th>
            </tr>
            <tr>
              <td>
                Players<br />
                &#149; Total:
                <span class="highlight">
                  <?php echo $players_total; ?>
                </span>
                <br />
                &#149; Currently Online:
                <span class="highlight">
                  <?php echo $players_online; ?>
                </span>
                <br />
                <br />
                The Bot
                <br />
                &#149; Uptime:<br>
                <span class="highlight">
                  <?php echo $uptime; ?>
                </span>
                <br />
                &#149; Transferred:<br>
                <span class="highlight">
                  <?php echo $traffic1; ?>
                </span>
                /
                <span class="highlight">
                  <?php echo $traffic2; ?>
                </span>
                <br />
                <br />
                The Channel
                <br />
                &#149; Current Size:
                <span class="highlight">
                  <?php echo $chan_size; ?>
                </span>
                <br />
                &#149; Channel Bans:
                <span class="highlight">
                  <?php echo $chan_bans; ?>
                </span>
                <br />
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>
<?php

/* close database connection */
if ($db)
	pg_close($db);

?>
