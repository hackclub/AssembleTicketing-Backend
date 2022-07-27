//
//  JWTCookieAndBearerAuthenticator.swift
//  AssembleTicketing
//
//  Created by Charlie Welsh on 7/26/22.
//

import Foundation
import Vapor
import JWT

extension JWTPayload where Self: Authenticatable {
	public static func cookieAcceptingAuthenticator() -> Authenticator {
		JWTCookieAcceptingPayloadAuthenticator<Self>()
	}
}

private struct JWTCookieAcceptingPayloadAuthenticator<Payload>: JWTCookieAcceptingAuthenticator
where Payload: JWTPayload & Authenticatable
{
	func authenticate(jwt: Payload, for request: Request) -> EventLoopFuture<Void> {
		request.auth.login(jwt)
		return request.eventLoop.makeSucceededFuture(())
	}
}

public protocol JWTCookieAcceptingAuthenticator: AsyncRequestAuthenticator, Authenticator {
	associatedtype Payload: JWTPayload
	func authenticate(jwt: Payload, for request: Request) -> EventLoopFuture<Void>
}

extension JWTCookieAcceptingAuthenticator {
	public func authenticate(request: Request) async throws {
		var token: String?
		// Bearer auth is provided
		if let bearerToken = request.headers.bearerAuthorization?.token {
			token = bearerToken
		// Cookie auth is provided
		} else if let cookieToken = request.cookies.all["hackclub-ticketing-auth"] {
			token = cookieToken.string
		}

		// Check that something provided the token
		guard let token = token else {
			throw Abort(.unauthorized, reason: "No authorization provided.")
		}

		try await self.authenticate(
			jwt: request.jwt.verify(token),
			for: request
		).get()
	}
}
