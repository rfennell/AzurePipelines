import "jest";

import {
    findFiles
} from "../src/AppyVersionToAngularFileFunctions";

describe ("Find files tests", () => {

    it ("should be able to find one file", () => {
        var filelist = findFiles ("test/testdata", "environment.ts.initial" , filelist);
        expect(filelist.length).toBe(2);
    });

    it ("should be able to use a wildcard to find two files", () => {
        var filelist = findFiles ("test/testdata", "environment\.(.*)\.ts" , filelist);
        expect(filelist.length).toBe(2);
    });
  });