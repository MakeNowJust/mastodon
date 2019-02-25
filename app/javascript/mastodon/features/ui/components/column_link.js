import React from 'react';
import PropTypes from 'prop-types';
import { Link } from 'react-router-dom';
import Icon from 'mastodon/components/icon';

const ColumnLink = ({ icon, text, to, href, method, badge, fontGrandOrder }) => {
  const badgeElement = typeof badge !== 'undefined' ? <span className='column-link__badge'>{badge}</span> : null;

  const iconElem = fontGrandOrder ?
    (<i className={`fgo fgo-${icon} column-link__icon`} />) :
    (<i className={`fa fa-fw fa-${icon} column-link__icon`} />);

  if (href) {
    return (
      <a href={href} className='column-link' data-method={method}>
        <Icon id={icon} fontGrandOrder={fontGrandOrder} fixedWidth className='column-link__icon' />
        {text}
        {badgeElement}
      </a>
    );
  } else {
    return (
      <Link to={to} className='column-link'>
        <Icon id={icon} fontGrandOrder={fontGrandOrder} fixedWidth className='column-link__icon' />
        {text}
        {badgeElement}
      </Link>
    );
  }
};

ColumnLink.propTypes = {
  icon: PropTypes.string.isRequired,
  text: PropTypes.string.isRequired,
  to: PropTypes.string,
  href: PropTypes.string,
  method: PropTypes.string,
  badge: PropTypes.node,
  fontGrandOrder: PropTypes.bool
};

export default ColumnLink;
