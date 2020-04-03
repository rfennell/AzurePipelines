import { expect } from "chai";
import { fixline, addSpace} from "../ReleaseNotesFunctions";
import fs  = require("fs");
// if you used the '@types/mocha' method to install mocha type definitions, uncomment the following line
import "mocha";
import { fstat } from "fs";
const del = require("del");

describe("Misc test", () => {
    it("should be able to process line", () => {

      var valuetoexpand = "value of abc";
      var datetime = new Date(2019, 9, 3, 16, 38, 0, 0);
      var line = "This is a line ${valuetoexpand} ${datetime.getDay()}/${datetime.getMonth()}/${datetime.getFullYear()} ${datetime.getHours()}:${datetime.getMinutes()}";
      var fixed = fixline(line);
      var processedLine = eval(fixed);
      expect(processedLine).to.equal("This is a line value of abc 4/9/2019 16:38");
    });

    it("should be able get an indent", () => {
      expect(addSpace(2)).to.equal("     "); // 5 spaces
    });

});

describe("Encoding fpr #661", () => {
  var filename = "encodingtest.md";
  it("should be able to encode a file", () => {
    var data = "Title for test: Корректная кодировка для элементов с кириллицей";
    fs.writeFileSync (filename, data, "utf8") ;
    var actual = fs.readFileSync (filename, "utf8").toString();
    expect(actual).to.equal(data);
  });

  after(function() {
    // remove the file if created
    del.sync(filename);
  });

});
