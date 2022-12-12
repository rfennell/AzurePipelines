import { assert } from "chai";
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
    assert(list[0].Id, "1");
    assert(list[1].Id, "3");
    assert(list[2].Id, "2");
    assert(list[3].Id, "4");
  });
});