import { expect } from "chai";
import { getMode, Mode, getModeTags} from "../ReleaseNotesFunctions";
// if you used the '@types/mocha' method to install mocha type definitions, uncomment the following line
import "mocha";

describe("Check the Mode extraction", () => {
    it("should be able to get CS mode when no tags", () => {
      expect(getMode("@@CSLOOP@@")).to.equal(Mode.CS);
    });

    it("should be able to get WI mode when no tags", () => {
      expect(getMode("@@WILOOP@@")).to.equal(Mode.WI);
    });

    it("should be able to get BODY mode when no tags", () => {
      expect(getMode("Any other than above two options")).to.equal(Mode.BODY);
    });

    it("should be able to handle lower case tags", () => {
      expect(getMode("@@wiLoop@@")).to.equal(Mode.WI);
    });

    it("should be able to get BODY mode when malformed tag CS", () => {
      expect(getMode("@@CSLOOP")).to.equal(Mode.BODY);
    });

    it("should be able to get BODY mode when malformed tag WI", () => {
      expect(getMode("@@WILOOP")).to.equal(Mode.BODY);
    });

    it("should be able to get WI when there is also a tag", () => {
      expect(getMode("@@WILOOP:TAG1@@")).to.equal(Mode.WI);
    });

    it("should be able to get tag from WI mode", () => {
      expect(getModeTags("@@WILOOP:TAG1@@")).to.deep.equal(["TAG1"]);
    });

    it("should be able to get two tags from WI mode", () => {
      expect(getModeTags("@@WILOOP:TAG1:TAG2@@")).to.deep.equal(["TAG1", "TAG2"]);
    });

    it("should be able to get two tags inc spaces from WI mode", () => {
      expect(getModeTags("@@WILOOP:TAG 1:TAG 2@@")).to.deep.equal(["TAG 1", "TAG 2"]);
    });

    it("should be able to get empty array if not tags", () => {
        expect(getModeTags("@@WILOOP@@")).to.deep.equal([]);
    });

});
