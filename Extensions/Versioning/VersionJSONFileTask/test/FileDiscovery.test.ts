import "jest";

import { findFiles,
  ProcessFile,
  getSplitVersionParts
} from "../src/AppyVersionToJSONFileFunctions";

describe ("Find files tests", () => {

  it ("should be able to find 6 files with recursion", () => {
      var filelist = findFiles ("test/testdata", "package.json.initial" , filelist, true);
      expect(filelist.length).toBe(6);
  });

  it ("should be able to find 2 files with no recursion", () => {
    var filelist = findFiles ("test/testdata", "package.json.initial" , filelist, false);
    expect(filelist.length).toBe(2);
  });

  it ("should be able to find 4 files with recursion and wildcard", () => {
    var filelist = findFiles ("test/testdata", "^package.json.initial" , filelist, true);
    expect(filelist.length).toBe(4);
  });

  it ("should be able to find 1 file with no recursion and wildcard", () => {
    var filelist = findFiles ("test/testdata", "^package.json.initial" , filelist, false);
    expect(filelist.length).toBe(1);
  });
});
