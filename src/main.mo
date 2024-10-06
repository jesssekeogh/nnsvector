import Principal "mo:base/Principal";
import Timer "mo:base/Timer";
import Blob "mo:base/Blob";
import T "./types";
import V "./vector";
import DeVeFi "mo:devefi";
import ICRC55 "mo:devefi/ICRC55";
import Node "mo:devefi/node";
import AccountIdentifier "mo:account-identifier";
import Account "mo:account";
import Hex "mo:encoding/Hex";
// import SnsLedgerInterface "mo:neuro/interfaces/sns_ledger_interface";

shared ({ caller = owner }) actor class () = this {

    let NTN_LEDGER = Principal.fromText("f54if-eqaaa-aaaaq-aacea-cai");
    let ICP_LEDGER = Principal.fromText("ryjl3-tyaaa-aaaaa-aaaba-cai");
    let ICP_GOVERNANCE = Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai");
    let THIS_CANISTER = Principal.fromText("7cotl-6aaaa-aaaam-ade2q-cai");

    let supportedLedgers : [Principal] = [
        ICP_LEDGER,
        NTN_LEDGER,
    ];

    stable let dvf_mem = DeVeFi.Mem();

    let dvf = DeVeFi.DeVeFi<system>({ mem = dvf_mem });
    dvf.add_ledger<system>(supportedLedgers[0], #icp);
    dvf.add_ledger<system>(supportedLedgers[1], #icrc);

    stable let node_mem = Node.Mem<T.Mem>();
    let nodes = Node.Node<system, T.CreateRequest, T.Mem, T.Shared, T.ModifyRequest>({
        mem = node_mem;
        dvf;
        settings = {
            ALLOW_TEMP_NODE_CREATION = true;
            TEMP_NODE_EXPIRATION_SEC = (60 * 60); // 1 hour
            MAX_SOURCES = 1 : Nat8;
            MAX_DESTINATIONS = 1 : Nat8;
            PYLON_NAME = "NNS Vector";
            PYLON_GOVERNED_BY = "Neutrinite DAO";
        };
        toShared = T.toShared;
        sourceMap = T.sourceMap;
        destinationMap = T.destinationMap;
        createRequest2Mem = T.createRequest2Mem;
        modifyRequestMut = T.modifyRequestMut;
        getDefaults = T.getDefaults;
        meta = T.meta;
        nodeMeta = T.nodeMeta;
    });

    let vector = V.NeuronVector({
        canister_id = THIS_CANISTER;
        icp_ledger = ICP_LEDGER;
        icp_governance = ICP_GOVERNANCE;
    });

    ignore Timer.recurringTimer<system>(
        #seconds(3),
        func() : async () {
            vector.sync_cycle(nodes);
        },
    );

    ignore Timer.recurringTimer<system>(
        #seconds(3),
        func() : async () {
            await* vector.async_cycle(nodes, dvf.get_ledger(ICP_LEDGER));
        },
    );

    ignore Timer.recurringTimer<system>(
        #seconds(60),
        func() : async () {
            await* vector.cache_cycle(nodes);
        },
    );

    public query func icrc55_get_nodefactory_meta() : async ICRC55.NodeFactoryMetaResp {
        nodes.icrc55_get_nodefactory_meta();
    };

    public shared ({ caller }) func icrc55_command(cmds : [ICRC55.Command<T.CreateRequest, T.ModifyRequest>]) : async [ICRC55.CommandResponse<T.Shared>] {
        nodes.icrc55_command(caller, cmds);
    };

    public shared ({ caller }) func icrc55_create_node(req : ICRC55.NodeRequest, creq : T.CreateRequest) : async Node.CreateNodeResp<T.Shared> {
        nodes.icrc55_create_node(caller, req, creq);
    };

    public query func icrc55_get_node(req : ICRC55.GetNode) : async ?Node.NodeShared<T.Shared> {
        nodes.icrc55_get_node(req);
    };

    public query ({ caller }) func icrc55_get_controller_nodes(req : ICRC55.GetControllerNodesRequest) : async [Node.NodeShared<T.Shared>] {
        nodes.icrc55_get_controller_nodes(caller, req);
    };

    public shared ({ caller }) func icrc55_delete_node(vid : ICRC55.LocalNodeId) : async ICRC55.DeleteNodeResp {
        nodes.icrc55_delete_node(caller, vid);
    };

    public shared ({ caller }) func icrc55_modify_node(vid : ICRC55.LocalNodeId, req : ?ICRC55.CommonModRequest, creq : ?T.ModifyRequest) : async Node.ModifyNodeResp<T.Shared> {
        nodes.icrc55_modify_node(caller, vid, req, creq);
    };

    public query func icrc55_get_defaults(id : Text) : async T.CreateRequest {
        nodes.icrc55_get_defaults(id);
    };

    // We need to start the vector manually once when canister is installed, because we can't init dvf from the body
    // https://github.com/dfinity/motoko/issues/4384
    // Sending tokens before starting the canister for the first time wont get processed
    public shared ({ caller }) func start() {
        assert (Principal.isController(caller));
        dvf.start<system>(Principal.fromActor(this));
        nodes.start<system>(Principal.fromActor(this));
    };

    // ---------- Debug functions -----------

    public func add_supported_ledger(id : Principal, ltype : { #icp; #icrc }) : () {
        dvf.add_ledger<system>(id, ltype);
    };

    public query func get_ledger_errors() : async [[Text]] {
        dvf.getErrors();
    };

    public query func get_ledgers_info() : async [DeVeFi.LedgerInfo] {
        dvf.getLedgersInfo();
    };

    // Dashboard explorer doesn't show icrc accounts in text format, this does
    // Hard to send tokens to Candid ICRC Accounts
    public query func get_node_addr(vid : Node.NodeId) : async ?{
        account_id : Text;
        icrc_account : Text;
        billing_account : Text;
    } {
        let ?node = nodes.icrc55_get_node(#id(vid)) else return null;

        let subaccount = Node.port2subaccount({
            vid;
            flow = #input;
            id = 0;
        });

        ?{
            account_id = AccountIdentifier.accountIdentifier(Principal.fromActor(this), subaccount) |> Blob.toArray(_) |> Hex.encode(_);
            icrc_account = Account.toText({
                owner = Principal.fromActor(this);
                subaccount = ?subaccount;
            });
            billing_account = Account.toText(node.billing.account);
        };
    };

    // TODO remove:
    
    // let NtnLedger = actor "f54if-eqaaa-aaaaq-aacea-cai" : SnsLedgerInterface.Self;

    // public func claim_back() : async Text {
    //     let ?node = nodes.icrc55_get_node(#id(0)) else return "No node found";

    //     let fee = await NtnLedger.icrc1_fee();
    //     let bal = await NtnLedger.icrc1_balance_of({
    //         owner = THIS_CANISTER;
    //         subaccount = null;
    //     });
    //     let #Ok(_) = await NtnLedger.icrc1_transfer({
    //         to = {
    //             owner = Principal.fromText("jv4ws-fbili-a35rv-xd7a5-xwvxw-trink-oluun-g7bcp-oq5f6-35cba-vqe");
    //             subaccount = null;
    //         };
    //         fee = null;
    //         memo = null;
    //         from_subaccount = null;
    //         created_at_time = null;
    //         amount = bal - fee;
    //     }) else return "Failed to transfer";

    //     return "Done";
    // };

};
