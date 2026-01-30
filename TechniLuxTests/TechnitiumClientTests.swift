import XCTest
@testable import TechniLux

final class TechnitiumClientTests: XCTestCase {

    func testApiResponseDecoding() throws {
        // Test successful response
        let successJson = """
        {
            "status": "ok",
            "response": {
                "zones": [
                    {
                        "name": "example.com",
                        "type": "Primary",
                        "internal": false,
                        "dnssecStatus": "Unsigned",
                        "disabled": false
                    }
                ]
            }
        }
        """

        let decoder = JSONDecoder()
        let response = try decoder.decode(ApiResponse<ZonesResponse>.self, from: successJson.data(using: .utf8)!)

        XCTAssertEqual(response.status, .ok)
        XCTAssertNotNil(response.response)
        XCTAssertEqual(response.response?.zones.count, 1)
        XCTAssertEqual(response.response?.zones.first?.name, "example.com")
    }

    func testErrorResponseDecoding() throws {
        let errorJson = """
        {
            "status": "error",
            "errorMessage": "Zone not found"
        }
        """

        let decoder = JSONDecoder()
        let response = try decoder.decode(ApiResponse<EmptyResponse>.self, from: errorJson.data(using: .utf8)!)

        XCTAssertEqual(response.status, .error)
        XCTAssertEqual(response.errorMessage, "Zone not found")
    }

    func testInvalidTokenResponseDecoding() throws {
        let tokenJson = """
        {
            "status": "invalid-token"
        }
        """

        let decoder = JSONDecoder()
        let response = try decoder.decode(ApiResponse<EmptyResponse>.self, from: tokenJson.data(using: .utf8)!)

        XCTAssertEqual(response.status, .invalidToken)
    }

    func testLoginResponseDecoding() throws {
        let loginJson = """
        {
            "status": "ok",
            "token": "abc123",
            "username": "admin",
            "displayName": "Administrator",
            "info": {
                "version": "12.0.0",
                "dnsServerDomain": "dns.local",
                "dnssecValidation": true
            }
        }
        """

        let decoder = JSONDecoder()
        let response = try decoder.decode(LoginResponse.self, from: loginJson.data(using: .utf8)!)

        XCTAssertEqual(response.status, .ok)
        XCTAssertEqual(response.token, "abc123")
        XCTAssertEqual(response.username, "admin")
        XCTAssertEqual(response.displayName, "Administrator")
        XCTAssertEqual(response.info?.version, "12.0.0")
    }

    func testDashboardStatsDecoding() throws {
        let statsJson = """
        {
            "status": "ok",
            "response": {
                "stats": {
                    "totalQueries": 12345,
                    "totalNoError": 10000,
                    "totalServerFailure": 100,
                    "totalNxDomain": 500,
                    "totalRefused": 50,
                    "totalAuthoritative": 2000,
                    "totalRecursive": 8000,
                    "totalCached": 5000,
                    "totalBlocked": 1500,
                    "totalDropped": 10,
                    "totalClients": 25,
                    "zones": 10,
                    "cachedEntries": 5000,
                    "allowedZones": 5,
                    "blockedZones": 100,
                    "allowListZones": 5,
                    "blockListZones": 100
                }
            }
        }
        """

        let decoder = JSONDecoder()
        let response = try decoder.decode(ApiResponse<StatsResponse>.self, from: statsJson.data(using: .utf8)!)

        XCTAssertEqual(response.status, .ok)
        XCTAssertEqual(response.response?.stats.totalQueries, 12345)
        XCTAssertEqual(response.response?.stats.totalBlocked, 1500)
        XCTAssertEqual(response.response?.stats.totalClients, 25)
    }

    func testRecordTypeDecoding() throws {
        for type in RecordType.allCases {
            let json = "\"\(type.rawValue)\""
            let decoded = try JSONDecoder().decode(RecordType.self, from: json.data(using: .utf8)!)
            XCTAssertEqual(decoded, type)
        }
    }

    func testZoneTypeDecoding() throws {
        for type in ZoneType.allCases {
            let json = "\"\(type.rawValue)\""
            let decoded = try JSONDecoder().decode(ZoneType.self, from: json.data(using: .utf8)!)
            XCTAssertEqual(decoded, type)
        }
    }

    func testAnyCodableDecoding() throws {
        let json = """
        {
            "string": "hello",
            "number": 42,
            "bool": true,
            "array": [1, 2, 3],
            "null": null
        }
        """

        let decoder = JSONDecoder()
        let decoded = try decoder.decode([String: AnyCodable].self, from: json.data(using: .utf8)!)

        XCTAssertEqual(decoded["string"]?.description, "hello")
        XCTAssertEqual(decoded["number"]?.description, "42")
        XCTAssertEqual(decoded["bool"]?.description, "true")
    }
}
