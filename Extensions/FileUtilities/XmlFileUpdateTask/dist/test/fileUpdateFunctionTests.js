"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const FileUpdateFunctions_1 = require("../src/FileUpdateFunctions");
const fs = require("fs");
const chai_1 = require("chai");
// if you used the '@types/mocha' method to install mocha type definitions, uncomment the following line
require("mocha");
function loggingFunction(msg) {
    // a way to dump the console message if needed, uncomment line below
    // console.log(msg);
}
describe('FindFiles function', () => {
    it('should find 3 matching files when using resursion and valid name', () => {
        let fileList;
        fileList = FileUpdateFunctions_1.findFiles("test/testdata", "*.xml", true, fileList);
        chai_1.expect(Object.keys(fileList).length).to.equal(3);
    });
    it('should find 2 matching files when not using resursion and valid name', () => {
        let fileList;
        fileList = FileUpdateFunctions_1.findFiles("test/testdata", "*.xml", false, fileList);
        chai_1.expect(Object.keys(fileList).length).to.equal(2);
    });
    it('should find no match with valid path and valid name', () => {
        let fileList;
        fileList = FileUpdateFunctions_1.findFiles("test/testdata", "*.XXX", true, fileList);
        chai_1.expect(Object.keys(fileList).length).to.equal(0);
    });
    it('should throw exception with invalid path', () => {
        let fileList;
        chai_1.expect(function () {
            FileUpdateFunctions_1.findFiles("test/xxxx", "*.xml", true, fileList);
        }).to.throw(Error);
    });
});
describe('ProcessFile function', () => {
    it('should update inner text on a node', () => {
        let rawContent = fs.readFileSync("test/testdata/1.xml").toString();
        let expected = fs.readFileSync("test/testdata/1a.updated").toString();
        let updateDoc = FileUpdateFunctions_1.processFile("/configuration/appSettings/add[@key='Enabled']", 'In memory test file', rawContent, "true", "", loggingFunction);
        loggingFunction(updateDoc.toString());
        chai_1.expect(updateDoc.toString()).to.equal(expected.toString());
    });
    it('should update named attribute on a node', () => {
        let rawContent = fs.readFileSync("test/testdata/1.xml").toString();
        let expected = fs.readFileSync("test/testdata/1b.updated").toString();
        let updateDoc = FileUpdateFunctions_1.processFile("/configuration/appSettings/add[@key='Version']", 'In memory test file', rawContent, "9.9.9.9", "value", loggingFunction);
        loggingFunction(updateDoc.toString());
        chai_1.expect(updateDoc.toString()).to.equal(expected.toString());
    });
});
//# sourceMappingURL=fileUpdateFunctionTests.js.map