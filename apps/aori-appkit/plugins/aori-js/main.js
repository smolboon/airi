var greeting = aori.call("capabilities", "snapshot", "aori.companion.greeting");
var files = aori.call("capabilities", "snapshot", "aori.files.read");
"greeting=" + greeting + " files=" + files;
