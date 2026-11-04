import { randomBytes } from 'node:crypto';
import { composeEnquiryEmail, type EnquiryInput } from '../domain/enquiry.js';
import { NotFoundError } from '../domain/errors.js';
import type { Money } from '../domain/product.js';
import { maskEmail, type Logger } from '../lib/logger.js';
import type { EmailSender } from '../ports/email-sender.js';
import type { ProductRepository } from '../ports/product-repository.js';

export interface EnquiryReceipt {
  readonly reference: string;
}

export interface EnquiryServiceOptions {
  readonly salesInbox: string;
  readonly generateReference?: () => string;
}

/** e.g. "ENQ-7F3A9C1B": short enough to read out on a phone call. */
export function generateEnquiryReference(): string {
  return `ENQ-${randomBytes(4).toString('hex').toUpperCase()}`;
}

function formatMoney(price: Money): string {
  return new Intl.NumberFormat('en-US', { style: 'currency', currency: price.currency }).format(
    price.amountMinor / 100,
  );
}

/**
 * Turns a customer's enquiry into an email to the sales inbox.
 *
 * The email is the record for the PoC: nothing is stored. The customer only
 * sees "Thank you" once the provider has accepted the email, so a failure is
 * reported back and they can retry instead of the enquiry being silently lost.
 */
export class EnquiryService {
  private readonly generateReference: () => string;

  constructor(
    private readonly products: ProductRepository,
    private readonly email: EmailSender,
    private readonly logger: Logger,
    private readonly options: EnquiryServiceOptions,
  ) {
    this.generateReference = options.generateReference ?? generateEnquiryReference;
  }

  async submit(enquiry: EnquiryInput): Promise<EnquiryReceipt> {
    const product = await this.products.getById(enquiry.productId);
    if (!product) throw new NotFoundError(`Product "${enquiry.productId}" was not found`);

    const reference = this.generateReference();
    const content = composeEnquiryEmail(reference, enquiry, product, formatMoney(product.price));

    await this.email.send({
      to: this.options.salesInbox,
      replyTo: enquiry.email,
      subject: content.subject,
      text: content.text,
    });

    this.logger.info(
      { reference, productId: product.id, customer: maskEmail(enquiry.email) },
      'Enquiry sent to sales inbox',
    );
    return { reference };
  }
}
