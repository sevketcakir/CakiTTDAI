class CakiTTDAI extends AIInfo {
  function GetAuthor()      { return "Şevket Umut ÇAKIR"; }
  function GetName()        { return "CakiTTDAI"; }
  function GetDescription() { return "Game AI of caki"; }
  function GetVersion()     { return 1; }
  function GetDate()        { return "2013-08-02"; }
  function CreateInstance() { return "CakiTTDAI"; }
  function GetShortName()   { return "CTAI"; }
  function GetAPIVersion()  { return "1.0"; }
}
RegisterAI(CakiTTDAI());