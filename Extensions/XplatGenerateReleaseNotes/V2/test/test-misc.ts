import { expect } from "chai";
import { fixline, addSpace} from "../ReleaseNotesFunctions";
// if you used the '@types/mocha' method to install mocha type definitions, uncomment the following line
import "mocha";

describe("Misc test", () => {
    it("should be able to process line", () => {

      var valuetoexpand = "value of abc";
      var datetime = new Date(2019, 9, 3, 16, 38, 0, 0);
      var line = "This is a line ${valuetoexpand} ${datetime.getDay()}/${datetime.getMonth()}/${datetime.getFullYear()} ${datetime.getHours()}:${datetime.getMinutes()}";
      var fixed = fixline(line);
      var processedLine = eval(fixed);
      expect(processedLine).to.equal("This is a line value of abc 4/9/2019 16:38");
    });

    it("should be able get an indent", () => {
      expect(addSpace(2)).to.equal("     "); // 5 spaces
    });

});
