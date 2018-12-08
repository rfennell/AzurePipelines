import { expect } from "chai";
import { fixRmUrl} from "../ReleaseNotesFunctions";
// if you used the '@types/mocha' method to install mocha type definitions, uncomment the following line
import "mocha";

describe("Check the URL reformating", () => {
    it("should not alter on on prem URL", () => {
      var url = "http://server:8080";
      expect(url).to.equal(fixRmUrl(url));
    });

    it("should alter a visualstudio.com URL", () => {
      var url = "https://myvsts.visualstudio.com";
      expect("https://myvsts.vsrm.visualstudio.com/defaultcollection").to.equal(fixRmUrl(url));
    });

    it("should alter a dev.azure.com URL", () => {
      var url = "https://dev.azure.com/myvsts";
      expect("https://vsrm.dev.azure.com/myvsts").to.equal(fixRmUrl(url));
    });
  });

//  export function fixRmUrl(url: string ): string {
//    var fixedUrl = url.replace(".visualstudio.com",  ".vsrm.visualstudio.com/defaultcollection")
//    return fixedUrl.replace("dev.azure.com",  "vsrm.dev.azure.com");
