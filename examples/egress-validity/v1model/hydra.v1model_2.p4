header eth_type2_t {
  bit<16> value;
}
header variables_t {
  bool good;
  bit<7> _pad;
}
struct hydra_header_t {
  eth_type2_t eth_type;
  variables_t variables;
}
struct hydra_metadata_t {
  bool reject0;
  bool allowed_ports;
  bit<16> switch_id;
  bit<16> allowed_ports_var0;
  bit<8> allowed_ports_var1;
}
parser CheckerHeaderParser(packet_in packet, out hydra_header_t hydra_header,
                           inout hydra_metadata_t hydra_metadata) {
  state start {
    packet.extract(hydra_header.eth_type);
    transition parse_variables;
  }
  state parse_variables {
    packet.extract(hydra_header.variables);
    transition accept;
  }
}
control CheckerHeaderDeparser(packet_out packet,
                              in hydra_header_t hydra_header) {
  apply
    {
    packet.emit(hydra_header.eth_type);
    packet.emit(hydra_header.variables);
  }
}
control telemetryControl(inout hydra_header_t hydra_header,
                         inout hydra_metadata_t hydra_metadata) {
  action init_cp_vars(bit<16> switch_id)
    {
    hydra_metadata.switch_id = switch_id;
  }
  table tb_init_cp_vars
    {
    key = {
      hydra_header.eth_type.isValid(): exact;
    }
    actions = {
      init_cp_vars;
    }
    size = 2;
  }
  action lkp_cp_dict_allowed_ports(bool allowed_ports)
    {
    hydra_metadata.allowed_ports = allowed_ports;
  }
  table tbl_lkp_cp_dict_allowed_ports
    {
    key =
      {
      hydra_metadata.allowed_ports_var0: exact;
      hydra_metadata.allowed_ports_var1: exact;
    }
    actions = {
      lkp_cp_dict_allowed_ports;
    }
    size = 64;
  }
  apply
    {
    tb_init_cp_vars.apply();
    hydra_metadata.allowed_ports_var0 = hydra_metadata.switch_id;
    hydra_metadata.allowed_ports_var1 = standard_metadata.egress_port;
    tbl_lkp_cp_dict_allowed_ports.apply();
    if (hydra_metadata.allowed_ports) {
      hydra_header.variables.good = false;
    }
  }
}

