#!/usr/bin/env node

/**
 * Brevo MCP Server
 *
 * A Model Context Protocol server for Brevo (formerly Sendinblue) email marketing platform.
 * Provides tools for sending transactional emails, managing contacts, lists, and campaigns.
 *
 * Environment Variables:
 * - BREVO_API_KEY: Your Brevo API key (required)
 * - BREVO_MCP_TOKEN: Your Brevo MCP token (optional, for official MCP integration)
 * - BREVO_SENDER_EMAIL: Default sender email (optional)
 * - BREVO_SENDER_NAME: Default sender name (optional)
 */

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  McpError,
  ErrorCode,
} from "@modelcontextprotocol/sdk/types.js";
import axios, { AxiosInstance } from "axios";

// Environment configuration
const BREVO_API_KEY = process.env.BREVO_API_KEY;
const BREVO_MCP_TOKEN = process.env.BREVO_MCP_TOKEN;
const DEFAULT_SENDER_EMAIL = process.env.BREVO_SENDER_EMAIL || "noreply@example.com";
const DEFAULT_SENDER_NAME = process.env.BREVO_SENDER_NAME || "Brevo MCP";

if (!BREVO_API_KEY && !BREVO_MCP_TOKEN) {
  throw new Error("BREVO_API_KEY or BREVO_MCP_TOKEN environment variable is required");
}

// Types
interface EmailRecipient {
  email: string;
  name?: string;
}

interface EmailAttachment {
  url?: string;
  content?: string;
  name: string;
}

interface ContactAttributes {
  [key: string]: string | number | boolean;
}

class BrevoServer {
  private server: Server;
  private axiosInstance: AxiosInstance;

  constructor() {
    this.server = new Server(
      {
        name: "brevo-mcp-server",
        version: "0.1.0",
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

    // Initialize axios with Brevo API
    this.axiosInstance = axios.create({
      baseURL: "https://api.brevo.com/v3",
      headers: {
        "api-key": BREVO_API_KEY,
        "Content-Type": "application/json",
        "Accept": "application/json",
      },
    });

    this.setupToolHandlers();

    // Error handling
    this.server.onerror = (error) => console.error("[Brevo MCP Error]", error);
    process.on("SIGINT", async () => {
      await this.server.close();
      process.exit(0);
    });
  }

  private setupToolHandlers() {
    // List available tools
    this.server.setRequestHandler(ListToolsRequestSchema, async () => ({
      tools: [
        {
          name: "send_transactional_email",
          description: "Send a transactional email via Brevo. Use for password resets, order confirmations, verification codes, etc.",
          inputSchema: {
            type: "object",
            properties: {
              to: {
                type: "array",
                items: {
                  type: "object",
                  properties: {
                    email: { type: "string", description: "Recipient email address" },
                    name: { type: "string", description: "Recipient name (optional)" }
                  },
                  required: ["email"]
                },
                description: "List of recipients"
              },
              subject: {
                type: "string",
                description: "Email subject line"
              },
              htmlContent: {
                type: "string",
                description: "HTML content of the email"
              },
              textContent: {
                type: "string",
                description: "Plain text content (optional, fallback)"
              },
              sender: {
                type: "object",
                properties: {
                  email: { type: "string" },
                  name: { type: "string" }
                },
                description: "Sender information (optional, uses defaults)"
              },
              replyTo: {
                type: "object",
                properties: {
                  email: { type: "string" },
                  name: { type: "string" }
                },
                description: "Reply-to address (optional)"
              },
              tags: {
                type: "array",
                items: { type: "string" },
                description: "Tags for categorizing emails"
              }
            },
            required: ["to", "subject", "htmlContent"]
          }
        },
        {
          name: "send_template_email",
          description: "Send an email using a pre-defined Brevo template. Templates are created in the Brevo dashboard.",
          inputSchema: {
            type: "object",
            properties: {
              to: {
                type: "array",
                items: {
                  type: "object",
                  properties: {
                    email: { type: "string" },
                    name: { type: "string" }
                  },
                  required: ["email"]
                },
                description: "List of recipients"
              },
              templateId: {
                type: "number",
                description: "ID of the Brevo template to use"
              },
              params: {
                type: "object",
                description: "Template parameters/variables (e.g., {name: 'John', code: '123456'})"
              },
              subject: {
                type: "string",
                description: "Override template subject (optional)"
              },
              tags: {
                type: "array",
                items: { type: "string" },
                description: "Tags for categorizing emails"
              }
            },
            required: ["to", "templateId"]
          }
        },
        {
          name: "create_contact",
          description: "Create a new contact in Brevo with optional attributes and list assignments",
          inputSchema: {
            type: "object",
            properties: {
              email: {
                type: "string",
                description: "Contact email address"
              },
              attributes: {
                type: "object",
                description: "Contact attributes (e.g., {FIRSTNAME: 'John', LASTNAME: 'Doe'})"
              },
              listIds: {
                type: "array",
                items: { type: "number" },
                description: "List IDs to add the contact to"
              },
              updateEnabled: {
                type: "boolean",
                description: "Update contact if already exists (default: false)"
              }
            },
            required: ["email"]
          }
        },
        {
          name: "update_contact",
          description: "Update an existing contact's attributes or list memberships",
          inputSchema: {
            type: "object",
            properties: {
              email: {
                type: "string",
                description: "Contact email address to update"
              },
              attributes: {
                type: "object",
                description: "Attributes to update"
              },
              listIds: {
                type: "array",
                items: { type: "number" },
                description: "Lists to add contact to"
              },
              unlinkListIds: {
                type: "array",
                items: { type: "number" },
                description: "Lists to remove contact from"
              }
            },
            required: ["email"]
          }
        },
        {
          name: "get_contact",
          description: "Get contact information by email address",
          inputSchema: {
            type: "object",
            properties: {
              email: {
                type: "string",
                description: "Contact email address"
              }
            },
            required: ["email"]
          }
        },
        {
          name: "delete_contact",
          description: "Delete a contact from Brevo",
          inputSchema: {
            type: "object",
            properties: {
              email: {
                type: "string",
                description: "Contact email address to delete"
              }
            },
            required: ["email"]
          }
        },
        {
          name: "get_lists",
          description: "Get all contact lists from Brevo",
          inputSchema: {
            type: "object",
            properties: {
              limit: {
                type: "number",
                description: "Number of lists to return (default: 50)"
              },
              offset: {
                type: "number",
                description: "Index of the first list to return (default: 0)"
              }
            }
          }
        },
        {
          name: "create_list",
          description: "Create a new contact list",
          inputSchema: {
            type: "object",
            properties: {
              name: {
                type: "string",
                description: "Name of the list"
              },
              folderId: {
                type: "number",
                description: "ID of the folder to create the list in"
              }
            },
            required: ["name", "folderId"]
          }
        },
        {
          name: "get_email_campaigns",
          description: "Get email campaigns with optional filtering",
          inputSchema: {
            type: "object",
            properties: {
              type: {
                type: "string",
                enum: ["classic", "trigger"],
                description: "Campaign type filter"
              },
              status: {
                type: "string",
                enum: ["suspended", "archive", "sent", "queued", "draft", "inProcess"],
                description: "Campaign status filter"
              },
              limit: {
                type: "number",
                description: "Number of campaigns to return"
              },
              offset: {
                type: "number",
                description: "Index of the first campaign"
              }
            }
          }
        },
        {
          name: "get_campaign_stats",
          description: "Get statistics for a specific email campaign",
          inputSchema: {
            type: "object",
            properties: {
              campaignId: {
                type: "number",
                description: "ID of the campaign"
              }
            },
            required: ["campaignId"]
          }
        },
        {
          name: "get_transactional_emails",
          description: "Get list of transactional emails sent",
          inputSchema: {
            type: "object",
            properties: {
              email: {
                type: "string",
                description: "Filter by recipient email (optional)"
              },
              templateId: {
                type: "number",
                description: "Filter by template ID (optional)"
              },
              messageId: {
                type: "string",
                description: "Filter by message ID (optional)"
              },
              startDate: {
                type: "string",
                description: "Start date (YYYY-MM-DD format)"
              },
              endDate: {
                type: "string",
                description: "End date (YYYY-MM-DD format)"
              },
              limit: {
                type: "number",
                description: "Number of results (default: 50)"
              }
            }
          }
        },
        {
          name: "get_account_info",
          description: "Get Brevo account information including plan details and usage",
          inputSchema: {
            type: "object",
            properties: {}
          }
        },
        {
          name: "get_senders",
          description: "Get list of verified sender addresses",
          inputSchema: {
            type: "object",
            properties: {}
          }
        }
      ]
    }));

    // Handle tool calls
    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      try {
        const { name, arguments: args } = request.params;

        switch (name) {
          case "send_transactional_email": {
            const { to, subject, htmlContent, textContent, sender, replyTo, tags } = args as {
              to: EmailRecipient[];
              subject: string;
              htmlContent: string;
              textContent?: string;
              sender?: EmailRecipient;
              replyTo?: EmailRecipient;
              tags?: string[];
            };

            const response = await this.axiosInstance.post("/smtp/email", {
              sender: sender || { email: DEFAULT_SENDER_EMAIL, name: DEFAULT_SENDER_NAME },
              to,
              subject,
              htmlContent,
              textContent,
              replyTo,
              tags,
            });

            return {
              content: [{
                type: "text",
                text: JSON.stringify({
                  success: true,
                  messageId: response.data.messageId,
                  message: `Email sent successfully to ${to.map(r => r.email).join(", ")}`
                }, null, 2)
              }]
            };
          }

          case "send_template_email": {
            const { to, templateId, params, subject, tags } = args as {
              to: EmailRecipient[];
              templateId: number;
              params?: Record<string, unknown>;
              subject?: string;
              tags?: string[];
            };

            const requestBody: Record<string, unknown> = {
              to,
              templateId,
              params,
              tags,
            };

            if (subject) {
              requestBody.subject = subject;
            }

            const response = await this.axiosInstance.post("/smtp/email", requestBody);

            return {
              content: [{
                type: "text",
                text: JSON.stringify({
                  success: true,
                  messageId: response.data.messageId,
                  message: `Template email (ID: ${templateId}) sent to ${to.map(r => r.email).join(", ")}`
                }, null, 2)
              }]
            };
          }

          case "create_contact": {
            const { email, attributes, listIds, updateEnabled } = args as {
              email: string;
              attributes?: ContactAttributes;
              listIds?: number[];
              updateEnabled?: boolean;
            };

            const response = await this.axiosInstance.post("/contacts", {
              email,
              attributes,
              listIds,
              updateEnabled: updateEnabled || false,
            });

            return {
              content: [{
                type: "text",
                text: JSON.stringify({
                  success: true,
                  id: response.data.id,
                  message: `Contact ${email} created successfully`
                }, null, 2)
              }]
            };
          }

          case "update_contact": {
            const { email, attributes, listIds, unlinkListIds } = args as {
              email: string;
              attributes?: ContactAttributes;
              listIds?: number[];
              unlinkListIds?: number[];
            };

            await this.axiosInstance.put(`/contacts/${encodeURIComponent(email)}`, {
              attributes,
              listIds,
              unlinkListIds,
            });

            return {
              content: [{
                type: "text",
                text: JSON.stringify({
                  success: true,
                  message: `Contact ${email} updated successfully`
                }, null, 2)
              }]
            };
          }

          case "get_contact": {
            const { email } = args as { email: string };

            const response = await this.axiosInstance.get(`/contacts/${encodeURIComponent(email)}`);

            return {
              content: [{
                type: "text",
                text: JSON.stringify(response.data, null, 2)
              }]
            };
          }

          case "delete_contact": {
            const { email } = args as { email: string };

            await this.axiosInstance.delete(`/contacts/${encodeURIComponent(email)}`);

            return {
              content: [{
                type: "text",
                text: JSON.stringify({
                  success: true,
                  message: `Contact ${email} deleted successfully`
                }, null, 2)
              }]
            };
          }

          case "get_lists": {
            const { limit = 50, offset = 0 } = args as { limit?: number; offset?: number };

            const response = await this.axiosInstance.get("/contacts/lists", {
              params: { limit, offset }
            });

            return {
              content: [{
                type: "text",
                text: JSON.stringify(response.data, null, 2)
              }]
            };
          }

          case "create_list": {
            const { name, folderId } = args as { name: string; folderId: number };

            const response = await this.axiosInstance.post("/contacts/lists", {
              name,
              folderId,
            });

            return {
              content: [{
                type: "text",
                text: JSON.stringify({
                  success: true,
                  id: response.data.id,
                  message: `List "${name}" created successfully`
                }, null, 2)
              }]
            };
          }

          case "get_email_campaigns": {
            const { type, status, limit = 50, offset = 0 } = args as {
              type?: string;
              status?: string;
              limit?: number;
              offset?: number;
            };

            const response = await this.axiosInstance.get("/emailCampaigns", {
              params: { type, status, limit, offset }
            });

            return {
              content: [{
                type: "text",
                text: JSON.stringify(response.data, null, 2)
              }]
            };
          }

          case "get_campaign_stats": {
            const { campaignId } = args as { campaignId: number };

            const response = await this.axiosInstance.get(`/emailCampaigns/${campaignId}`);

            return {
              content: [{
                type: "text",
                text: JSON.stringify({
                  campaign: response.data.name,
                  status: response.data.status,
                  statistics: response.data.statistics,
                  createdAt: response.data.createdAt,
                  sentDate: response.data.sentDate,
                }, null, 2)
              }]
            };
          }

          case "get_transactional_emails": {
            const { email, templateId, messageId, startDate, endDate, limit = 50 } = args as {
              email?: string;
              templateId?: number;
              messageId?: string;
              startDate?: string;
              endDate?: string;
              limit?: number;
            };

            const response = await this.axiosInstance.get("/smtp/emails", {
              params: { email, templateId, messageId, startDate, endDate, limit }
            });

            return {
              content: [{
                type: "text",
                text: JSON.stringify(response.data, null, 2)
              }]
            };
          }

          case "get_account_info": {
            const response = await this.axiosInstance.get("/account");

            return {
              content: [{
                type: "text",
                text: JSON.stringify({
                  email: response.data.email,
                  firstName: response.data.firstName,
                  lastName: response.data.lastName,
                  companyName: response.data.companyName,
                  plan: response.data.plan,
                  credits: response.data.plan?.credits,
                  relay: response.data.relay,
                }, null, 2)
              }]
            };
          }

          case "get_senders": {
            const response = await this.axiosInstance.get("/senders");

            return {
              content: [{
                type: "text",
                text: JSON.stringify(response.data, null, 2)
              }]
            };
          }

          default:
            throw new McpError(
              ErrorCode.MethodNotFound,
              `Unknown tool: ${name}`
            );
        }
      } catch (error) {
        if (axios.isAxiosError(error)) {
          const errorMessage = error.response?.data?.message ||
                              error.response?.data?.error ||
                              error.message;
          throw new McpError(
            ErrorCode.InternalError,
            `Brevo API error: ${errorMessage}`
          );
        }
        throw error;
      }
    });
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error("Brevo MCP server running on stdio");
  }
}

const server = new BrevoServer();
server.run().catch(console.error);
