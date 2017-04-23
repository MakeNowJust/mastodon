import PropTypes from 'prop-types';
import { Link } from 'react-router';

const ColumnLink = ({ icon, text, to, href, method, hideOnMobile, fontGrandOrder }) => {
  const iconElem = fontGrandOrder ?
    (<i className={`fgo fgo-${icon} column-link__icon`} />) :
    (<i className={`fa fa-fw fa-${icon} column-link__icon`} />)
  if (href) {
    return (
      <a href={href} className={`column-link ${hideOnMobile ? 'hidden-on-mobile' : ''}`} data-method={method}>
        {iconElem}
        {text}
      </a>
    );
  } else {
    return (
      <Link to={to} className={`column-link ${hideOnMobile ? 'hidden-on-mobile' : ''}`}>
        {iconElem}
        {text}
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
  hideOnMobile: PropTypes.bool,
  fontGrandOrder: PropTypes.bool
};

export default ColumnLink;
