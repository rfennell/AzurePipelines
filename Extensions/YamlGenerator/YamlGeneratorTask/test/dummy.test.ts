import { expect } from "chai";
import { generateYaml } from "../src/Generate-YAMLDocumentation";
// if you used the '@types/mocha' method to install mocha type definitions, uncomment the following line
import "mocha";

describe("A empty set of tests to check the CI/CD system", () => {
    it("should be able to compare two numbers", () => {
      expect(1 === 1);
    });
  });

// describe("A test to allow local running", () => {
//   it("should be able to generate YAML", () => {
//     generateYaml("C:\\projects\\github\\AzurePipelines\\Extensions\\DevTestLab", "c:\\tmp", "TEST");
//   });
// });
