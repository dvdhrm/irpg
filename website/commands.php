<?php

/*
 * Command List
 * Written 2011 by David Herrmann
 */

/*
 * This does not contain any dynamic content, yet. Some values may be read from
 * the database but this isn't really required.
 * TODO: correctly inline the code
 */

?>
<strong class="highlight">
  <span class="big">GSRPG Command List</span>
</strong>
<br />
<br />
&#149;
<span class="highlight">
  /msg IRPG REGISTER &lt;username&gt;
  &lt;password&gt; &lt;email@address&gt; &lt;class name&gt;
</span>
<br />
&nbsp;&nbsp;<strong>Function</strong>: this command registers you a new player with IRPG
<br />
&nbsp;&nbsp;<strong>Parameters</strong>
<br />



					&nbsp;&nbsp;&nbsp;&nbsp;&lt;username&gt;: Your unique identifier to the bot. This name is what will appear to other players (case-sensitive)<br /> 
					&nbsp;&nbsp;&nbsp;&nbsp;&lt;password&gt;: Password used to login both to the bot and to the website<br /> 
					&nbsp;&nbsp;&nbsp;&nbsp;&lt;email@address&gt;: From time to time I may send out announcements via email. Eventually you will also be able<br /> 
					&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;to use this feature to change your username/password from the website<br /> 
					&nbsp;&nbsp;&nbsp;&nbsp;&lt;class name&gt;: A short description of your player (mine is "drunken college student", for instance)<br /> 
					&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;you <strong>do not</strong> need to include a "the" at the beginning<br /> 
					&nbsp;&nbsp;<strong>Example</strong>: /msg IRPG REGISTER Jake abc123 my@email.com Drunken College Student<br /> 
					<br /><br /> 
					&#149;
					<span class="highlight">/msg IRPG LOGIN &lt;username&gt; &lt;password&gt;</span> 
					<br /> 
					&nbsp;&nbsp;<strong>Function</strong>: logs you back in to the bot<br /> 
					&nbsp;&nbsp;<strong>Parameters</strong><br /> 
					&nbsp;&nbsp;&nbsp;&nbsp;&lt;username&gt;: Your unique identifier to the bot. This name is what will appear to other players<br /> 
					&nbsp;&nbsp;&nbsp;&nbsp;&lt;password&gt;: Password used to login both to the bot and to the website<br /> 
					&nbsp;&nbsp;<strong>Example</strong>: /msg IRPG LOGIN Jake abc123<br /> 
					<br /><br /> 
					&#149;
					<span class="highlight">/msg IRPG LOGOUT</span> 
					<br /> 
					&nbsp;&nbsp;<strong>Function</strong>: logs you out from the game (this command does incur a penalty)<br /> 
					&nbsp;&nbsp;<strong>Example</strong>: /msg IRPG LOGOUT<br /> 
					<br /><br /> 
					&#149;
					<span class="highlight">/msg IRPG WHOAMI</span> 
					<br /> 
					&nbsp;&nbsp;<strong>Function</strong>: displays your username, level, class, time to next level, and itemsum<br /> 
					&nbsp;&nbsp;<strong>Example</strong>: /msg IRPG WHOAMI<br /> 
					<br /><br /> 
					&#149;
					<span class="highlight">/msg IRPG ITEMS</span> 
					<br /> 
					&nbsp;&nbsp;<strong>Function</strong>: displays a list of your items, including any unique items you may have found<br /> 
					&nbsp;&nbsp;<strong>Example</strong>: /msg IRPG ITEMS<br /> 
					<br /><br /> 
					&#149;
					<span class="highlight">/msg IRPG QUEST</span> 
					<br /> 
					&nbsp;&nbsp;<strong>Function</strong>: displays the active quest, if any<br /> 
					&nbsp;&nbsp;<strong>Example</strong>: /msg IRPG QUEST<br /> 
					<br /><br /> 
					&#149;
					<span class="highlight">/msg IRPG CLASS &lt;new class name&gt;</span> 
					<br /> 
					&nbsp;&nbsp;<strong>Function</strong>: changes your class with the bot<br /> 
					&nbsp;&nbsp;<strong>Parameters</strong><br /> 
					&nbsp;&nbsp;&nbsp;&nbsp;&lt;class name&gt;: A short description of your player (mine is "drunken college student", for instance)<br /> 
					&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;you <strong>do not</strong> need to include a "the" at the beginning<br /> 
					&nbsp;&nbsp;<strong>Example</strong>: /msg IRPG CLASS Drunken College Student<br /> 
					<br /><br /> 
					&#149;
					<span class="highlight">/msg IRPG NOTICE &lt;on/off&gt;</span> 
					<br /> 
					&nbsp;&nbsp;<strong>Function</strong>: toggles whether the bot sends you messages over privmsg or over notice<br /> 
					&nbsp;&nbsp;<strong>Parameters</strong><br /> 
					&nbsp;&nbsp;&nbsp;&nbsp;&lt;on/off&gt;: "on" means the bot sends you messages over notice; "off" means privmsg<br /> 
					&nbsp;&nbsp;<strong>Example</strong>: /msg IRPG NOTICE on<br /> 
					<br /><br /> 
					&#149;
					<span class="highlight">/msg IRPG WHOIS &lt;username&gt;</span> 
					<br /> 
					&nbsp;&nbsp;<strong>Function</strong>: equivalent to doing a "whoami" on someone else (case-sensitive)<br /> 
					&nbsp;&nbsp;<strong>Parameters</strong><br /> 
					&nbsp;&nbsp;&nbsp;&nbsp;&lt;username&gt;: The username of the target player<br /> 
					&nbsp;&nbsp;<strong>Example</strong>: /msg IRPG WHOIS Jake<br /> 
					<br /><br /> 
					&#149;
					<span class="highlight">/msg IRPG LOOKUP &lt;nickname&gt;</span> 
					<br /> 
					&nbsp;&nbsp;<strong>Function</strong>: equivalent of whois, except looks up a person by nickname<br /> 
					&nbsp;&nbsp;<strong>Parameters</strong><br /> 
					&nbsp;&nbsp;&nbsp;&nbsp;&lt;nickname&gt;: The nickname of the target player<br /> 
					&nbsp;&nbsp;<strong>Example</strong>: /msg IRPG LOOKUP Jake<br /> 
					<br /><br /> 
					&#149;
					<span class="highlight">/msg IRPG JOIN &lt;teamname&gt; [password]</span> 
					<br /> 
					&nbsp;&nbsp;<strong>Function</strong>: joins the specified IRPG team<br /> 
					&nbsp;&nbsp;<strong>Parameters</strong><br /> 
					&nbsp;&nbsp;&nbsp;&nbsp;&lt;teamname&gt;: The team name you wish to join (case-insensitive)<br /> 
					&nbsp;&nbsp;&nbsp;&nbsp;[password]: Some teams may require passwords to join; if so, the bot will ask for it<br /> 
					&nbsp;&nbsp;<strong>Example</strong>: /msg IRPG JOIN SomeRandomTeamName helloworld<br /> 
					<br /><br /> 
					&#149;
					<span class="highlight">/msg IRPG LEAVE</span> 
					<br /> 
					&nbsp;&nbsp;<strong>Function</strong>: leaves your team (if you are on one)<br /> 
					&nbsp;&nbsp;<strong>Example</strong>: /msg IRPG LEAVE<br /> 
					<br /><br /> 
					&#149;
					<span class="highlight">/msg IRPG TOP10</span> 
					<br /> 
					&nbsp;&nbsp;<strong>Function</strong>: displays the IRPG leaderboard<br /> 
					&nbsp;&nbsp;<strong>Example</strong>: /msg IRPG TOP10<br /> 
					<br /><br /> 
					&#149;
					<span class="highlight">/msg IRPG UP</span> 
					<br /> 
					&nbsp;&nbsp;<strong>Function</strong>: ops/voices you in the bot channel, if enabled<br /> 
					&nbsp;&nbsp;<strong>Example</strong>: /msg IRPG UP<br /> 
					<br /><br /> 
					&#149;
					<span class="highlight">/msg IRPG CHALLENGE [username]</span> 
					<br /> 
					&nbsp;&nbsp;<strong>Function</strong>: activates a manual challenge<br /> 
					&nbsp;&nbsp;<strong>Notes</strong>: manual challenges are entirely new to IRPG2, and as such, they require a good bit of explanation.<br /> 
					&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Manual challenges work in one of two ways; first, you can specify the person you want to challenge.<br /> 
					&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;The amount of time you can gain or lose is directly proportional to the itemsum of the person you challenge.<br /> 
					&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;For instance, if you have an itemsum of 200, and you challenge someone with an itemsum of 400, you can<br /> 
					&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;gain (or lose) more time than you would by challenging someone with an itemsum of 220. Likewise, if you<br /> 
					&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;have an itemsum of 400, and you challenge a new player with an itemsum of 5, you will gain virtually no<br /> 
					&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;time at all. The other option available to you is to not specify the person you want to challenge, and let<br /> 
					&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;the bot select the challengee. It does by selecting the person with the itemsum directly above and directly<br /> 
					&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;you, and then randomly picking one or the other. With this method, you will not gain as much time as you<br /> 
					&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;could by specifying a player, but you will not lose as much time if you lose the challenge either. To keep<br /> 
					&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;everything in proportion, each time you use a challenge, the amount of time you must wait before you may<br /> 
					&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;challenge again increases exponentially. You will only hurt yourself by using a large number of<br /> 
					&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;challenges all at once. Also, please note that the first time you use this command, this help message<br /> 
					&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;is displayed to you to familiarize you with the way challenges work. After that, challenges start counting.<br />



&nbsp;&nbsp;
<strong>Parameters</strong>
<br />
&nbsp;&nbsp;&nbsp;&nbsp;
[username]: if you wish, you may specify the player you want to challenge
<br />
&nbsp;&nbsp;<strong>Example</strong>: /msg IRPG CHALLENGE Jake
<br />
&nbsp;&nbsp;<strong>Example</strong>: /msg IRPG CHALLENGE
<br />
<?php

/* End of Command List */

?>
