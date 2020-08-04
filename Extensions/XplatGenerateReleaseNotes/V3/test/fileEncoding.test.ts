import { expect } from "chai";
import fs  = require("fs");
// if you used the '@types/mocha' method to install mocha type definitions, uncomment the following line
import "mocha";
import { fstat } from "fs";
const del = require("del");

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
