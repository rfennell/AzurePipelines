import { expect, assert } from "chai";
// if you used the '@types/mocha' method to install mocha type definitions, uncomment the following line
import "mocha";

// as test to prove the logic not testing actual code
describe("a sort test suite", () => {
  it("should be able to list", () => {
    var list = [
      { WorkItemType: "Bug", Id: "1" },
      { WorkItemType: "PBI", Id: "2" },
      { WorkItemType: "Bug", Id: "3" },
      { WorkItemType: "PBI", Id: "4" }
    ];

    list = list.sort((a, b) => (a.WorkItemType > b.WorkItemType) ? 1 : (a.WorkItemType === b.WorkItemType) ? ((a.Id > b.Id) ? 1 : -1) : -1 );

    console.log(list);
  });
});