import { expect } from "chai";
// if you used the '@types/mocha' method to install mocha type definitions, uncomment the following line
import "mocha";

import {
    findFiles
} from "../src/AppyVersionToAngularFileFunctions";

describe ("Find files tests", () => {

    it ("should be able to find one file", () => {
        var filelist = findFiles ("test/testdata", "environment.ts.initial" , filelist);
        expect(filelist.length).to.equal(2);
    });

    it ("should be able to use a wildcard to find two files", () => {
        var filelist = findFiles ("test/testdata", "environment\.(.*)\.ts" , filelist);
        expect(filelist.length).to.equal(2);
    });
  });