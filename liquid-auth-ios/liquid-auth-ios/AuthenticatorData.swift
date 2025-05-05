import Foundation


// struct AuthenticatorData {
    
//     init() {}
    
//     func toData() -> Data {
//         return Data()
//     }
// }

struct AuthenticatorData: Codable {
   let rpIdHash: Data
   let userPresent: Bool
   let userVerified: Bool
   let atIncluded: Bool
   let edIncluded: Bool
   var signCount: UInt32 // 32-bit unsigned big-endian integer
   let attestedCredentialData: Data?
   let extensions: Data?

   // Define these as static constants
   static let upMask: UInt8 = 1      // User present result
   static let uvMask: UInt8 = 1 << 2 // User verified result
   static let atMask: UInt8 = 1 << 6 // Attested credential data included
   static let edMask: UInt8 = 1 << 7 // Extension data included

   init(_ rpIdHash: Data, _ up: Bool, _ uv: Bool, _ count: UInt32,
        _ attestedCredData: Data?, _ extensions: Data?) {
       self.rpIdHash = rpIdHash
       self.userPresent = up
       self.userVerified = uv
       self.atIncluded = attestedCredData != nil ? true : false
       self.edIncluded = extensions != nil
       self.signCount = count
       self.attestedCredentialData = attestedCredData
       self.extensions = extensions
   }

   func createFlags(up userPresent: Bool, uv userVerified: Bool, at atIncluded: Bool, ed edIncluded: Bool) -> UInt8 {
       var flags: UInt8 = 0
       if userPresent { flags = flags | AuthenticatorData.upMask }
       if userVerified { flags = flags | AuthenticatorData.uvMask }
       if atIncluded { flags = flags | AuthenticatorData.atMask }
       if edIncluded { flags = flags | AuthenticatorData.edMask }
       return flags
   }

   func toData() -> Data {
       let flags = self.createFlags(up: self.userPresent, uv: self.userVerified, at: self.atIncluded, ed: self.edIncluded)
       let flagsData = flags.toData()
       let signCountData = self.signCount.toDataBigEndian()
       var data = rpIdHash + flagsData + signCountData
       if let attestedCredentialData = self.attestedCredentialData {
           data += attestedCredentialData
       }
       if let extensions = self.extensions {
           data += extensions
       }
       return data
   }
}
