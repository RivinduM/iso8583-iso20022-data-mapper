import ballerinax/mi;
import ballerina/xmldata;
import ballerina/lang.'decimal as decimal0;
import iso/iso8583;
import iso/iso20022;

# Transform iso 8583 json object to iso 20022 xml.
#
# + isoJsonInput - iso 8583 json object
# + return - iso 20022 xml or error
@mi:ConnectorInfo {}
public function iso8583To20022(string isoJsonInput) returns xml {

        json|error isoJson = isoJsonInput.fromJsonString();
        if (isoJson is error) {
            return xml `<Error>Error while reading iso 8583 JSON</Error>`;
        }
        
        xml?|xmldata:Error xmlValue = xmldata:fromJson(isoJson);
        if xmlValue is xmldata:Error {
            return xml `<Error>Error while converting ISO 8583 JSON to XML</Error>`;
        }

        if (xmlValue is xml) {
            iso8583:ISO8583_0200|xmldata:Error isoMessage = xmldata:fromXml(xmlValue);
            if (isoMessage is xmldata:Error) {
                return xml `<Error>Error while converting ISO 8583 XML to record</Error>`;
            }
            map<anydata>|error transformedMsg = transformIso8583to20022(isoMessage);
            if (transformedMsg is error) {
                return xml `<Error>Error while transforming ISO 8583 to ISO 20022</Error>`;
            }
            map<anydata> transformedMsgWithRoot = {"Document": {FIToFICstmrCdtTrf: transformedMsg}};

            xml|error result = xmldata:toXml(transformedMsgWithRoot);
            if (result is error) {
                return xml `<Error>Error while converting ISO 20022 record to XML</Error>`;
            }
            return result;
        }
        return xml `<Error>Error while converting ISO 8583 JSON to XML</Error>`;
}


function transformIso8583to20022(iso8583:ISO8583_0200 iso8583) returns iso20022:FIToFICstmrCdtTrf|error => {
    GrpHdr: {

        NbOfTxs: 1,
        CreDtTm: iso8583.TransmissionDateTime,
        MsgId: iso8583.SystemTraceAuditNumber,
        SttlmInf: {
            SttlmMtd: getSttlmMtd(iso8583)
        }
    },
    CdtTrfTxInf: [
        {

            CdtrAgt: {
                FinInstnId: iso8583.AcquiringInstitutionIdentificationCode

            },
            DbtrAcct: {
                Id: iso8583.PrimaryAccountNumber ?: ""
            },
            IntrBkSttlmAmt: {
                Ccy: iso8583.CurrencyCodeTransaction,
                \#content: check decimal0:fromString(iso8583.AmountTransaction)
            },
            DbtrAgt: {
                FinInstnId: iso8583.CardAccepterTerminalIdentification ?: ""
            },
            Dbtr: {
                number: iso8583.CardAccepterIdentificationCode ?: ""
            },
            PmtId: {
                EndToEndId: iso8583.SystemTraceAuditNumber + iso8583.RetrievalReferenceNumber

            },
            ChrgBr: "DEBT"

        }
    ],
    SplmtryData: [
        {
            Envlp: {
                key: iso8583.AuthorizationNumber != () ? "AuthorizationNumber" : "",
                value: iso8583.AuthorizationNumber ?: ""
            }
        }

    ]
};


type Document record {
    iso20022:FIToFICstmrCdtTrf FIToFICstmrCdtTrf;
};

function getSttlmMtd(iso8583:ISO8583_0200 iso8583) returns string {
    if (iso8583.AcquiringInstitutionIdentificationCode != "" && iso8583.MessageAuthenticationCode != ()) {
        return "CLRG";
    } else if (iso8583.AcquiringInstitutionIdentificationCode != "" && iso8583.ReceivingInstitutionIdentificationCode == ()) {
        return "INDA";
    }
    return "INGA";
}
