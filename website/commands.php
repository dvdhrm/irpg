<?php

/*
 * Command List
 * Written 2011 by David Herrmann
 */

/*
 * This does not contain any dynamic content, yet. Some values may be read from
 * the database but this isn't really required.
 */

?>
<strong class="highlight">
  <span class="big">GSRPG Command List</span>
</strong>
<ul>
  <li class="cmdlist">
    <span class="highlight">
      /msg IRPG REGISTER &lt;username&gt;
      &lt;password&gt; &lt;email@address&gt; &lt;class name&gt;
    </span>
    <br />
    <strong>Function</strong>: this command registers you a new player with IRPG
    <br />
    <strong>Parameters</strong>
    <ul>
      <li>
        &lt;username&gt;: Your unique identifier to the bot. This name is
        what will appear to other players (case-sensitive)
      </li>
      <li>
        &lt;password&gt;: Password used to login both to the bot and to the
        website
      </li>
      <li>
        &lt;email@address&gt;: From time to time I may send out announcements
        via email. Eventually you will also be able
        to use this feature to change your username/password from the website
      </li>
      <li>
        &lt;class name&gt;: A short description of your player (mine is
        "drunken college student", for instance) you <strong>do not</strong>
        need to include a "the" at the beginning
      </li>
    </ul>
    <strong>Example</strong>: /msg IRPG REGISTER Jake abc123 my@email.com
    Drunken College Student
  </li>
  <li class="cmdlist">
    <span class="highlight">
      /msg IRPG LOGIN &lt;username&gt; &lt;password&gt;
    </span>
    <br>
    <strong>Function</strong>: logs you back in to the bot
    <br />
    <strong>Parameters</strong>
    <ul>
      <li>
        &lt;username&gt;: Your unique identifier to the bot. This name is what
        will appear to other players
      </li>
      <li>
        &lt;password&gt;: Password used to login both to the bot and to the
        website
      </li>
    </ul>
    <strong>Example</strong>: /msg IRPG LOGIN Jake abc123
  </li>
  <li class="cmdlist">
    <span class="highlight">/msg IRPG LOGOUT</span>
    <br />
    <strong>Function</strong>: logs you out from the game (this command does
    incur a penalty)
    <br />
    <strong>Example</strong>: /msg IRPG LOGOUT
  </li>
  <li class="cmdlist">
    <span class="highlight">/msg IRPG WHOAMI</span>
    <br />
    <strong>Function</strong>: displays your username, level, class, time to
    next level, and itemsum
    <br />
    <strong>Example</strong>: /msg IRPG WHOAMI
  </li>
  <li class="cmdlist">
    <span class="highlight">/msg IRPG ITEMS</span>
    <br />
    <strong>Function</strong>: displays a list of your items, including any
    unique items you may have found
    <br />
    <strong>Example</strong>: /msg IRPG ITEMS
  </li>
  <li class="cmdlist">
    <span class="highlight">/msg IRPG QUEST</span>
    <br />
    <strong>Function</strong>: displays the active quest, if any
    <br />
    <strong>Example</strong>: /msg IRPG QUEST
  </li>
  <li class="cmdlist">
    <span class="highlight">/msg IRPG CLASS &lt;new class name&gt;</span>
    <br />
    <strong>Function</strong>: changes your class with the bot
    <br />
    <strong>Parameters</strong>
    <ul>
      <li>
        &lt;class name&gt;: A short description of your player (mine is
        "drunken college student", for instance)
        you <strong>do not</strong> need to include a "the" at the beginning
      </li>
    </ul>
    <strong>Example</strong>: /msg IRPG CLASS Drunken College Student
  </li>
  <li class="cmdlist">
    <span class="highlight">/msg IRPG NOTICE &lt;on/off&gt;</span>
    <br />
    <strong>Function</strong>: toggles whether the bot sends you messages over
    privmsg or over notice
    <br />
    <strong>Parameters</strong>
    <ul>
      <li>
        &lt;on/off&gt;: "on" means the bot sends you messages over notice;
        "off" means privmsg
      </li>
    </ul>
    <strong>Example</strong>: /msg IRPG NOTICE on
  </li>
  <li class="cmdlist">
    <span class="highlight">/msg IRPG WHOIS &lt;username&gt;</span>
    <br />
    <strong>Function</strong>: equivalent to doing a "whoami" on someone else
    (case-sensitive)
    <br />
    <strong>Parameters</strong>
    <ul>
      <li>&lt;username&gt;: The username of the target player</li>
    </ul>
    <strong>Example</strong>: /msg IRPG WHOIS Jake
  </li>
  <li class="cmdlist">
    <span class="highlight">/msg IRPG LOOKUP &lt;nickname&gt;</span>
    <br />
    <strong>Function</strong>: equivalent of whois, except looks up a person by
    nickname
    <br />
    <strong>Parameters</strong>
    <ul>
      <li>&lt;nickname&gt;: The nickname of the target player</li>
    </ul>
    <strong>Example</strong>: /msg IRPG LOOKUP Jake
  </li>
  <li class="cmdlist">
    <span class="highlight">/msg IRPG JOIN &lt;teamname&gt; [password]</span>
    <br />
    <strong>Function</strong>: joins the specified IRPG team
    <br />
    <strong>Parameters</strong>
    <ul>
      <li>&lt;teamname&gt;: The team name you wish to join
      (case-insensitive)</li>
      <li>[password]: Some teams may require passwords to join; if so, the bot
      will ask for it</li>
    </ul>
    <strong>Example</strong>: /msg IRPG JOIN SomeRandomTeamName helloworld
  </li>
  <li class="cmdlist">
    <span class="highlight">/msg IRPG LEAVE</span>
    <br />
    <strong>Function</strong>: leaves your team (if you are on one)
    <br />
    <strong>Example</strong>: /msg IRPG LEAVE
  </li>
  <li class="cmdlist">
    <span class="highlight">/msg IRPG TOP10</span>
    <br />
    <strong>Function</strong>: displays the IRPG leaderboard
    <br />
    <strong>Example</strong>: /msg IRPG TOP10
  </li>
  <li class="cmdlist">
    <span class="highlight">/msg IRPG UP</span>
    <br />
    <strong>Function</strong>: ops/voices you in the bot channel, if enabled
    <br />
    <strong>Example</strong>: /msg IRPG UP
  </li>
  <li class="cmdlist">
    <span class="highlight">/msg IRPG CHALLENGE [username]</span>
    <br />
    <strong>Function</strong>: activates a manual challenge
    <br />
    <strong>Notes</strong>: manual challenges are entirely new to IRPG2, and as
    such, they require a good bit of explanation. Manual challenges work in one
    of two ways; first, you can specify the person you want to challenge.
    The amount of time you can gain or lose is directly proportional to the itemsum of the person you challenge.
    For instance, if you have an itemsum of 200, and you challenge someone with an itemsum of 400, you can
    gain (or lose) more time than you would by challenging someone with an itemsum of 220. Likewise, if you
    have an itemsum of 400, and you challenge a new player with an itemsum of 5, you will gain virtually no
    time at all. The other option available to you is to not specify the person you want to challenge, and let
    the bot select the challengee. It does by selecting the person with the itemsum directly above and directly
    you, and then randomly picking one or the other. With this method, you will not gain as much time as you
    could by specifying a player, but you will not lose as much time if you lose the challenge either. To keep
    everything in proportion, each time you use a challenge, the amount of time you must wait before you may
    challenge again increases exponentially. You will only hurt yourself by using a large number of
    challenges all at once. Also, please note that the first time you use this command, this help message
    is displayed to you to familiarize you with the way challenges work. After that, challenges start counting.
    <br>
    <strong>Parameters</strong>
    <ul>
      <li>[username]: if you wish, you may specify the player you want to
      challenge</li>
    </ul>
    <strong>Example</strong>: /msg IRPG CHALLENGE Jake
    <br />
    <strong>Example</strong>: /msg IRPG CHALLENGE
  </li>
</ul>
<?php

/* End of Command List */

?>
