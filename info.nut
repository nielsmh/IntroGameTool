require("version.nut");

class FMainClass extends GSInfo {
	function GetAuthor()		{ return "nielsm"; }
	function GetName()			{ return "Intro Game Tools"; }
	function GetDescription() 	{ return "Tools to help build intro screen games."; }
	function GetVersion()		{ return SELF_VERSION; }
	function GetDate()			{ return "2021-09-05"; }
	function CreateInstance()	{ return "MainClass"; }
	function GetShortName()		{ return "jfs1"; } // Replace this with your own unique 4 letter string
	function GetAPIVersion()	{ return "1.11"; }
	function GetURL()			{ return ""; }

	function GetSettings() {
	}
}

RegisterGS(FMainClass());
