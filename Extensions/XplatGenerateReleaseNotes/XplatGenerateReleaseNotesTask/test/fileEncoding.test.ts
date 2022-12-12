import { expect } from "chai";
import * as fs from "fs";
import * as fse from "fs-extra";

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
    fse.removeSync(filename);
  });

});