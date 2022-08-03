import JWT

/// An extremely simple token for handling nothing but ticketing.
struct TicketToken: JWTPayload {
	func verify(using signer: JWTSigner) throws { }

	var subject: SubjectClaim
}
