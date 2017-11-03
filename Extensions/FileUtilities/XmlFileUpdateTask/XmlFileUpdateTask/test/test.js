"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const FileUpdate_1 = require("../XmlFileUpdateTask.src/FileUpdate");
const chai_1 = require("chai");
// if you used the '@types/mocha' method to install mocha type definitions, uncomment the following line
require("mocha");
describe('Hello function', () => {
    it('should return hello world', () => {
        const result = FileUpdate_1.default();
        chai_1.expect(result).to.equal('Hello World!');
    });
});
//# sourceMappingURL=test.js.map