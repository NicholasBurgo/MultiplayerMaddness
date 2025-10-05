---@class NetTransport
---@field start fun(role: "server"|"client", opts: table): boolean
---@field stop fun(): nil
---@field send fun(channel: string, msg: table, to?: string): nil
---@field poll fun(handler: fun(ev: {type:string, from?:string, channel?:string, msg?:table})): nil
return {}
