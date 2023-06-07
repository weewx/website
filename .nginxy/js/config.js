//
/*------------------------------------*\
    Nginxy
    by @lfelipe1501

    Theme name: Nginxy
    Theme author: @lfelipe1501
\*------------------------------------*/
// Configure .nginxy here:
var websiteName = "WeeWX";
var websiteURL = "http://www.weewx.com";
// End of normal settings.
//
//

$(document).ready(function() {
  // Working on nginx HTML and applying settings.
  var text = $("#dirname").text();
  var array = text.split("/");
  var last = array[array.length - 2];
  var currentDir = last.charAt(0).toUpperCase() + last.slice(1);

  // Truncate long folder names.
  if (currentDir.length > 19) {
    currentDir = currentDir.substring(0, 18) + "...";
  }

  // Updating page title.
  document.title = websiteName + ": " + currentDir;

  $("#dirname").html(currentDir);

  // Establish supported formats.
  var formats = [
    "7z",
    "avi",
    "bat",
    "bin",
    "bmp",
    "c",
    "c++",
    "cmd",
    "css",
    "deb",
    "doc",
    "docx",
    "exe",
    "gif",
    "gz",
    "gzip",
    "html",
    "ico",
    "iso",
    "java",
    "jpeg",
    "jpg",
    "js",
    "mp3",
    "mp4",
    "msg",
    "ogg",
    "pdf",
    "php",
    "png",
    "ppt",
    "pptx",
    "psd",
    "py",
    "rar",
    "raw",
    "rpm",
    "sh",
    "sql",
    "svg",
    "swf",
    "tiff",
    "torrent",
    "txt",
    "wav",
    "wma",
    "wmv",
    "xls",
    "xlsx",
    "zip"
  ];

  // Scan all files in the directory, check the extensions and show the right MIME-type image.
  $("td a").each(function() {
    var found = 0;
    var arraySplit = $(this)
      .attr("href")
      .split(".");
    var fileExt = arraySplit[arraySplit.length - 1];
    var oldText;

    for (var i = 0; i < formats.length; i++) {
      if (fileExt.toLowerCase() === formats[i].toLowerCase()) {
        found = 1;
        oldText = $(this).text();
        $(this).html(
          '<img class="icons" src="/.nginxy/images/icons/' +
            formats[i] +
            '.png" style="margin:0 4px -4px 0"/></a>' +
            oldText
        );
        return;
      }
    }

    // Add an icon for the go-back link.
    if (
      $(this)
        .text()
        .indexOf("Parent directory") >= 0
    ) {
      found = 1;
      oldText = $(this).text();
      $(this).html(
        '<img class="icons" src="/.nginxy/images/icons/home.png" ' +
          'style="margin:0 4px -4px 0"/>' +
          oldText
      );
      return;
    }

    // Check for folders as they don't have extensions.
    if (
      $(this)
        .attr("href")
        .substr($(this).attr("href").length - 1) === "/"
    ) {
      found = 1;
      oldText = $(this).text();
      $(this).html(
        '<img class="icons" src="/.nginxy/images/icons/folder.png" ' +
          'style="margin:0 4px -4px 0"/>' +
          oldText.substring(0, oldText.length - 1)
      );

      // Fix for annoying jQuery behaviour where inserted spaces are treated as new elements -- which breaks my search.
      var string = " " + $($(this)[0].nextSibling).text();

      // Copy the original meta-data string, append a space char and save it over the old string.
      $($(this)[0].nextSibling).remove();
      $(this).after(string);
      return;
    }

    // File format not supported by Better Listings, so let's load a generic icon.
    if (found === 0) {
      oldText = $(this).text();
      $(this).html(
        '<img class="icons" src="/.nginxy/images/icons/error.png" ' +
          'style="margin:0 4px -4px 0"/>' +
          oldText
      );
    }
  });
});
